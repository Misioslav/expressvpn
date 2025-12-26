#!/bin/bash
set -euo pipefail

log() {
    echo "[start] $*"
}

has_ctl() {
    command -v expressvpnctl >/dev/null 2>&1
}

xvpn_cmd() {
    expressvpnctl "$@"
}

restore_resolver() {
    local resolv="/etc/resolv.conf"

    if [[ -f "$resolv" ]]; then
        cp "$resolv" "${resolv}.bak"
        umount "$resolv" &>/dev/null || true
        cp "${resolv}.bak" "$resolv"
        rm -f "${resolv}.bak"
    fi
}

restart_service() {
    local service_name=""
    if [[ -f /etc/init.d/expressvpn-service ]]; then
        service_name="expressvpn-service"
    elif [[ -f /etc/init.d/expressvpn ]]; then
        service_name="expressvpn"
    fi

    if [[ -z "$service_name" ]]; then
        log "Unable to locate expressvpn init script"
        exit 1
    fi

    service "$service_name" stop >/dev/null 2>&1 || true
    if service_output=$(service "$service_name" start 2>&1); then
        log "$service_output"
    else
        log "$service_output"
        log "Service ${service_name} start failed!"
        exit 1
    fi
}

wait_for_daemon() {
    local attempts=10
    local delay=2
    local attempt

    for attempt in $(seq 1 "$attempts"); do
        if xvpn_cmd status >/dev/null 2>&1; then
            return 0
        fi
        sleep "$delay"
    done

    return 1
}

activate_account() {
    local output
    if [[ -z ${CODE:-} ]]; then
        log "Activation code is required (CODE)."
        exit 1
    fi
    if ! wait_for_daemon; then
        log "ExpressVPN daemon not responding; activation aborted."
        exit 1
    fi
    local code_file
    code_file=$(mktemp)
    printf '%s' "${CODE}" >"${code_file}"
    if ! output=$(expressvpnctl --timeout 60 login "${code_file}" 2>&1); then
        rm -f "${code_file}"
        if grep -qi "Already logged into account" <<<"$output"; then
            log "$output"
            log "Already logged in; skipping activation."
            return
        fi
        log "$output"
        log "Activation command failed!"
        exit 1
    fi
    rm -f "${code_file}"
    if ! expressvpnctl background enable >/dev/null 2>&1; then
        log "Unable to enable expressvpnctl background mode."
    fi
}

set_protocol() {
    local value="$1"
    if [[ -z "$value" ]]; then
        value="auto"
    fi
    value="${value,,}"
    case "$value" in
        auto|lightwayudp|lightwaytcp|openvpnudp|openvpntcp|wireguard) ;;
        *)
            log "Unsupported PROTOCOL value: ${value}"
            exit 1
            ;;
    esac
    if ! expressvpnctl set protocol "$value" 2>/dev/null; then
        log "Unable to set protocol to ${value}"
        exit 1
    fi
}

configure_preferences() {
    set_protocol "${PROTOCOL:-lightwayudp}"
    bash /expressvpn/uname.sh
    if ! expressvpnctl set allowlan "${ALLOW_LAN:-true}" >/dev/null 2>&1; then
        log "Unable to set allowlan to ${ALLOW_LAN:-true}"
    fi

    if ! xvpn_cmd connect "${SERVER:-smart}"; then
        log "Unable to connect to ${SERVER:-smart}"
        exit 1
    fi
    wait_for_connection
    apply_lan_routes
}

apply_dns_whitelist() {
    local dns_list="${WHITELIST_DNS:-}"
    [[ -z "$dns_list" ]] && return

    dns_list="${dns_list//,/ }"
    for addr in $dns_list; do
        iptables -A xvpn_dns_ip_exceptions -d "${addr}"/32 -p udp -m udp --dport 53 -j ACCEPT
        log "Allowing DNS server traffic in iptables: ${addr}"
    done
}

start_socks_proxy() {
    if [[ ${SOCKS:-off} != "on" ]]; then
        return
    fi

    if { [[ -n ${SOCKS_USER:-} ]] && [[ -z ${SOCKS_PASS:-} ]]; } || \
       { [[ -z ${SOCKS_USER:-} ]] && [[ -n ${SOCKS_PASS:-} ]]; }; then
        log "Error: Both SOCKS_USER and SOCKS_PASS must be set, or neither."
        exit 1
    fi

    local args=()
    if [[ ${SOCKS_LOGS:-true} == "false" ]]; then
        args+=("-q")
    fi
    if [[ ${SOCKS_AUTH_ONCE:-false} == "true" ]]; then
        args+=("-1")
    fi
    if [[ -n ${SOCKS_WHITELIST:-} ]]; then
        args+=("-w" "${SOCKS_WHITELIST}")
    fi
    if [[ -n ${SOCKS_USER:-} ]]; then
        args+=("-u" "${SOCKS_USER}" "-P" "${SOCKS_PASS}")
    fi

    args+=("-i" "${SOCKS_IP:-0.0.0.0}" "-p" "${SOCKS_PORT:-1080}")
    log "Starting microsocks on ${SOCKS_IP:-0.0.0.0}:${SOCKS_PORT:-1080}"
    microsocks "${args[@]}" &
}

start_metrics_fallback() {
    local port="$1"
    local path="$2"
    local listen_addr="TCP-LISTEN:${port},reuseaddr,fork"
    local exec_cmd
    printf -v exec_cmd 'env METRICS_EXPECTED_PATH=%q /expressvpn/metrics-server.sh' "$path"
    log "Starting metrics fallback server on port ${port} via socat"
    socat -T30 "${listen_addr}" EXEC:"${exec_cmd}",pipes >>/tmp/metrics-socat.log 2>&1 &
    local socat_pid=$!
    sleep 1
    if ! kill -0 "${socat_pid}" 2>/dev/null; then
        log "Unable to launch metrics fallback server, see /tmp/metrics-socat.log for details"
    fi
}

start_metrics_exporter() {
    if [[ ${METRICS_PROMETHEUS:-off} != "on" ]]; then
        return
    fi

    local port="${METRICS_PORT:-9797}"
    local path="${METRICS_PATH:-/metrics.cgi}"

    if [[ "${path}" != /* ]]; then
        log "METRICS_PATH must be absolute (received: ${path})"
        exit 1
    fi

    if [[ "${path}" != *.cgi ]]; then
        log "METRICS_PATH must end with .cgi (received: ${path})"
        exit 1
    fi

    local dest="/expressvpn/www${path}"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    mkdir -p "${dest_dir}"
    cp /expressvpn/metrics.cgi "${dest}"
    chmod +x "${dest}"

    cat <<'EOF' >/expressvpn/www/httpd.conf
*.cgi:/bin/bash
EOF

    log "Starting metrics exporter on port ${port} path ${path}"
    local err_log="/tmp/metrics-httpd.log"
    rm -f "${err_log}"
    busybox httpd -f -p "0.0.0.0:${port}" -h /expressvpn/www -c /expressvpn/www/httpd.conf >"${err_log}" 2>&1 &
    local httpd_pid=$!
    sleep 1
    if ! kill -0 "${httpd_pid}" 2>/dev/null; then
        log "Metrics exporter failed to start (see ${err_log}): $(cat "${err_log}" 2>/dev/null)"
        local unpriv_port_start
        unpriv_port_start=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo 1024)
        log "Hint: ensure METRICS_PORT is >= ${unpriv_port_start}, run with CAP_NET_BIND_SERVICE, or start the container with '--security-opt seccomp=unconfined'."
        start_metrics_fallback "${port}" "${path}"
    fi
    allow_inbound_port "${port}"
}

start_control_server() {
    if [[ ${CONTROL_SERVER:-off} != "on" ]]; then
        return
    fi

    log "Starting ExpressVPN control server on ${CONTROL_IP:-0.0.0.0}:${CONTROL_PORT:-8000}"
    chmod +x /expressvpn/control-server.sh 2>/dev/null || true
    /expressvpn/control-server.sh &
    allow_inbound_port "${CONTROL_PORT:-8000}"
}

allow_inbound_port() {
    local port="$1"
    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --dport "${port}" -j ACCEPT >/dev/null 2>&1 || \
            iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT
    fi
}

apply_lan_routes() {
    if [[ ${ALLOW_LAN:-true} != "true" ]]; then
        return
    fi
    if [[ -z ${LAN_CIDR:-} ]]; then
        return
    fi
    local gateway
    gateway=$(ip route show default 2>/dev/null | awk 'NR==1 {print $3}')
    if [[ -z "$gateway" ]]; then
        log "Unable to determine default gateway for LAN routes."
        return
    fi
    local cidr_list="${LAN_CIDR//,/ }"
    for cidr in $cidr_list; do
        ip route replace "$cidr" via "$gateway" dev eth0
        log "Added LAN route for ${cidr} via ${gateway}"
    done
}

wait_for_connection() {
    local attempts=15
    local delay=2
    local attempt
    for attempt in $(seq 1 "$attempts"); do
        if [[ "$(expressvpnctl get connectionstate 2>/dev/null || true)" == "Connected" ]]; then
            return 0
        fi
        sleep "$delay"
    done
    log "Timed out waiting for VPN connection."
}

main() {
    if ! has_ctl; then
        log "expressvpnctl not found; installation failed."
        exit 1
    fi
    restore_resolver
    restart_service
    activate_account
    start_metrics_exporter
    configure_preferences
    apply_dns_whitelist
    start_socks_proxy
    start_control_server

    if [[ $# -gt 0 ]]; then
        exec "$@"
    fi

    sleep infinity & wait "$!"
}

main "$@"
