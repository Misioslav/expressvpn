#!/bin/bash
set -euo pipefail

log() {
    echo "[start] $*"
}

auto_update() {
    if [[ ${AUTO_UPDATE:-off} != "on" ]]; then
        return
    fi

    log "Auto-update enabled, updating expressvpn package"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        install --only-upgrade --no-install-recommends expressvpn
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/* /var/log/*.log
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
    if sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn; then
        :
    else
        log "Unable to patch expressvpn init script"
        exit 1
    fi

    if service_output=$(service expressvpn restart 2>&1); then
        log "$service_output"
    else
        log "$service_output"
        log "Service expressvpn restart failed!"
        exit 1
    fi
}

activate_account() {
    local output
    if output=$(expect -f /expressvpn/activate.exp "${CODE:-}"); then
        if grep -Eq "Please activate your account|Activation failed" <<<"$output"; then
            log "$output"
            log "Activation reported failure!"
            exit 1
        fi
    else
        log "$output"
        log "Activation command failed!"
        exit 1
    fi
}

configure_preferences() {
    expressvpn preferences set preferred_protocol "${PROTOCOL:-lightway_udp}"
    expressvpn preferences set lightway_cipher "${CIPHER:-chacha20}"
    expressvpn preferences set send_diagnostics false
    expressvpn preferences set block_trackers true
    bash /expressvpn/uname.sh
    expressvpn preferences set auto_connect true

    if ! expressvpn connect "${SERVER:-smart}"; then
        log "Unable to connect to ${SERVER:-smart}"
        exit 1
    fi
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

main() {
    auto_update
    restore_resolver
    restart_service
    activate_account
    configure_preferences
    apply_dns_whitelist
    start_socks_proxy

    if [[ $# -gt 0 ]]; then
        exec "$@"
    fi

    sleep infinity & wait "$!"
}

main "$@"
