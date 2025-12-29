#!/bin/bash
set -euo pipefail

# ExpressVPN Control Server
# HTTP API for controlling ExpressVPN container

CONTROL_PORT="${CONTROL_PORT:-8000}"
CONTROL_IP="${CONTROL_IP:-0.0.0.0}"
AUTH_CONFIG="${AUTH_CONFIG:-/expressvpn/config.toml}"

declare -a ROLE_NAMES=()
declare -a ROLE_AUTH_TYPES=()
declare -a ROLE_USERS=()
declare -a ROLE_PASSWORDS=()
declare -a ROLE_KEYS=()
declare -a ROLE_ROUTES=()
ROLE_COUNT=0
AUTH_CONFIG_MTIME=""

AUTH_FAILURE_STATUS="401 Unauthorized"
AUTH_FAILURE_HEADER=""
AUTH_FAILURE_MESSAGE="Authentication required"

log() {
    echo "[control-server] $*" >&2
}


http_response() {
    local status_code="$1"
    local content_type="${2:-application/json}"
    local body="${3:-}"
    local extra_headers="${4:-}"
    local body_length

    body_length=$(printf '%s' "$body" | LC_ALL=C wc -c | tr -d ' ')

    printf 'HTTP/1.1 %s\r\n' "$status_code"
    printf 'Content-Type: %s\r\n' "$content_type"
    printf 'Content-Length: %s\r\n' "$body_length"
    printf 'Connection: close\r\n'
    if [[ -n "$extra_headers" ]]; then
        printf '%s\r\n' "$extra_headers"
    fi
    printf '\r\n%s' "$body"
}

uppercase() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

trim() {
    if [[ $# -gt 0 ]]; then
        printf '%s' "$1"
    else
        cat
    fi | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

load_auth_config() {
    ROLE_NAMES=()
    ROLE_AUTH_TYPES=()
    ROLE_USERS=()
    ROLE_PASSWORDS=()
    ROLE_KEYS=()
    ROLE_ROUTES=()
    ROLE_COUNT=0

    AUTH_CONFIG_ERROR=""

    if [[ ! -f "$AUTH_CONFIG" ]]; then
        local env_auth="${CONTROL_AUTH_TYPE:-}"
        if [[ -n "$env_auth" ]]; then
            local routes_input="${CONTROL_AUTH_ROUTES:-*}"
            local formatted_routes=""
            IFS=',' read -ra route_parts <<< "$routes_input"
            if (( ${#route_parts[@]} == 0 )); then
                route_parts=('*')
            fi
            for route in "${route_parts[@]}"; do
                route="${route#${route%%[![:space:]]*}}"
                route="${route%${route##*[![:space:]]}}"
                [[ -z "$route" ]] && continue
                if [[ -n "$formatted_routes" ]]; then
                    formatted_routes+=$'\n'
                fi
                formatted_routes+="$route"
            done
            [[ -z "$formatted_routes" ]] && formatted_routes="*"

            ROLE_NAMES+=("${CONTROL_AUTH_NAME:-env-role}")
            ROLE_AUTH_TYPES+=("$env_auth")
            ROLE_USERS+=("${CONTROL_AUTH_USER:-}")
            ROLE_PASSWORDS+=("${CONTROL_AUTH_PASSWORD:-}")
            ROLE_KEYS+=("${CONTROL_API_KEY:-}")
            ROLE_ROUTES+=("$formatted_routes")
            ROLE_COUNT=1
        fi
        return
    fi

    local mtime
    mtime=$(stat -c %Y "$AUTH_CONFIG" 2>/dev/null || echo "")
    if [[ "$mtime" == "$AUTH_CONFIG_MTIME" && "$ROLE_COUNT" -gt 0 ]]; then
        return
    fi

    AUTH_CONFIG_MTIME="$mtime"

    local parse_output
    if ! parse_output=$(python3 - "$AUTH_CONFIG" <<'PY'
import sys
try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover - fallback for Debian bullseye
    import tomli as tomllib
path = sys.argv[1]
try:
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
except Exception as exc:
    print(f"ERROR\t{exc}", file=sys.stderr)
    sys.exit(1)
roles = data.get("roles", [])
for role in roles:
    name = role.get("name", "") or ""
    auth = role.get("auth", "") or ""
    username = role.get("username", "") or ""
    password = role.get("password", "") or ""
    api_key = role.get("api_key", "") or role.get("apikey", "") or ""
    routes = role.get("routes") or []
    encoded_routes = "\x1f".join(routes)
    print("\x1e".join([name, auth, username, password, api_key, encoded_routes]))
PY
    ); then
        log "Failed to parse auth configuration at $AUTH_CONFIG"
        ROLE_COUNT=0
        AUTH_CONFIG_ERROR="parse"
        return
    fi

    while IFS=$'\x1e' read -r name auth username password api_key routes_line; do
        ROLE_NAMES+=("$name")
        ROLE_AUTH_TYPES+=("$auth")
        ROLE_USERS+=("$username")
        ROLE_PASSWORDS+=("$password")
        ROLE_KEYS+=("$api_key")
        ROLE_ROUTES+=("${routes_line//$'\x1f'/$'\n'}")
    done <<< "$parse_output"

    ROLE_COUNT=${#ROLE_NAMES[@]}
}

role_allows_route() {
    local idx="$1"
    local route="$2"

    if [[ -z "${ROLE_ROUTES[idx]}" ]]; then
        return 0
    fi

    while IFS= read -r allowed || [[ -n "$allowed" ]]; do
        allowed="$(trim "$allowed")"
        [[ -z "$allowed" ]] && continue
        if [[ "$allowed" == "$route" || "$allowed" == "*" ]]; then
            return 0
        fi
    done <<< "${ROLE_ROUTES[idx]}"

    return 1
}

extract_auth_value() {
    local header="$1"
    printf '%s' "$header" | sed -n 's/^[Aa]uthorization:[[:space:]]*//p'
}

extract_api_key() {
    local header="$1"
    printf '%s' "$header" | sed -n 's/^[Xx]-[Aa][Pp][Ii]-[Kk]ey:[[:space:]]*//p'
}

decode_basic_credentials() {
    local encoded="$1"
    printf '%s' "$encoded" | base64 -d 2>/dev/null || true
}

check_auth() {
    local auth_header="$1"
    local api_key_header="$2"
    local method="$3"
    local path="$4"

    load_auth_config

    AUTH_FAILURE_STATUS="401 Unauthorized"
    AUTH_FAILURE_HEADER=""
    AUTH_FAILURE_MESSAGE="Authentication required"

    [[ "$path" == "" ]] && path="/"
    local method_upper
    method_upper=$(uppercase "$method")
    local route="${method_upper} ${path}"

    if [[ -n "$AUTH_CONFIG_ERROR" ]]; then
        AUTH_FAILURE_STATUS="500 Internal Server Error"
        AUTH_FAILURE_MESSAGE="Authentication configuration invalid"
        AUTH_FAILURE_HEADER=""
        return 1
    fi

    if [[ "$ROLE_COUNT" -eq 0 ]]; then
        return 0
    fi

    local header_value route_allowed=false failure_header=""
    header_value=$(extract_auth_value "$auth_header")
    local api_key_value=""
    api_key_value=$(extract_api_key "$api_key_header")

    for (( idx=0; idx<ROLE_COUNT; idx++ )); do
        if ! role_allows_route "$idx" "$route"; then
            continue
        fi
        route_allowed=true

        local auth_type="${ROLE_AUTH_TYPES[idx]}"
        if [[ "$auth_type" == "apikey" ]]; then
            auth_type="api_key"
        fi
        case "$auth_type" in
            ""|"basic")
                failure_header='WWW-Authenticate: Basic realm="ExpressVPN"'
                if [[ -z "$header_value" ]]; then
                    continue
                fi
                if [[ "$header_value" =~ ^[Bb]asic[[:space:]]+(.+)$ ]]; then
                    local decoded
                    decoded=$(decode_basic_credentials "${BASH_REMATCH[1]}")
                    local username password
                    IFS=':' read -r username password <<< "${decoded:-:}"
                    if [[ -n "$username" && -n "$password" ]] && \
                       [[ "$username" == "${ROLE_USERS[idx]}" && "$password" == "${ROLE_PASSWORDS[idx]}" ]]; then
                        return 0
                    fi
                fi
                ;;
            "api_key")
                if [[ -n "$api_key_value" ]]; then
                    if [[ "$api_key_value" == "${ROLE_KEYS[idx]}" && -n "$api_key_value" ]]; then
                        return 0
                    fi
                    continue
                fi
                if [[ "$header_value" =~ ^[Bb]earer[[:space:]]+(.+)$ ]]; then
                    local token="${BASH_REMATCH[1]}"
                    if [[ "$token" == "${ROLE_KEYS[idx]}" && -n "$token" ]]; then
                        return 0
                    fi
                fi
                ;;
            "none")
                return 0
                ;;
            *)
                continue
                ;;
        esac
    done

    if [[ "$route_allowed" == false ]]; then
        AUTH_FAILURE_STATUS="403 Forbidden"
        AUTH_FAILURE_MESSAGE="Route not permitted for configured credentials"
        AUTH_FAILURE_HEADER=""
    else
        AUTH_FAILURE_STATUS="401 Unauthorized"
        AUTH_FAILURE_MESSAGE="Authentication required"
        AUTH_FAILURE_HEADER="$failure_header"
    fi

    return 1
}

get_expressvpn_status() {
    local status connected="false" server="" ip="" state=""
    if status=$(expressvpnctl status 2>/dev/null); then
        state=$(timeout 3s expressvpnctl get connectionstate 2>/dev/null | trim || true)
        if [[ "$state" == "Connected" ]]; then
            connected="true"
        fi
        server=$(timeout 3s expressvpnctl get region 2>/dev/null | trim || true)
        ip=$(timeout 3s expressvpnctl get vpnip 2>/dev/null | trim || true)
        jq -n --arg connected "$connected" \
              --arg server "$server" \
              --arg ip "$ip" \
              --arg status "$status" \
              '{connected: ($connected == "true"), server: $server, ip: $ip, status: $status}'
    else
        jq -n '{connected: false, server: "", ip: "", status: "ExpressVPN not running"}'
    fi
}

get_servers() {
    local servers
    if servers=$(expressvpnctl get regions 2>/dev/null); then
        printf '%s\n' "$servers" | jq -R -s 'split("\n") | map(select(length>0))'
    else
        jq -n '[]'
    fi
}

get_dns_info() {
    local resolv_conf="/etc/resolv.conf"
    local dns_entries=()
    if [[ -f "$resolv_conf" ]]; then
        while read -r line; do
            line=${line%$'\r'}
            if [[ "$line" =~ ^nameserver[[:space:]]+([^[:space:]]+) ]]; then
                dns_entries+=("${BASH_REMATCH[1]}")
            fi
        done < "$resolv_conf"
    fi

    local dns_json
    if ((${#dns_entries[@]} == 0)); then
        dns_json='[]'
    else
        dns_json=$(printf '%s\n' "${dns_entries[@]}" | jq -R -s 'split("\n") | map(select(length>0))')
    fi
    local resolv_content
    resolv_content=$(cat "$resolv_conf" 2>/dev/null || printf '')

    jq -n --argjson dns "$dns_json" --arg resolv "$resolv_content" '
        {
            dns_servers: $dns,
            resolv_conf: $resolv
        }'
}

get_public_ip() {
    local ip_info="" ip="" country="" city="" org=""

    if [[ -n "${BEARER:-}" ]]; then
        ip_info=$(curl -fsSL --max-time 10 -H "Authorization: Bearer ${BEARER}" "https://ipinfo.io" 2>/dev/null || printf '')
    fi

    if [[ -n "$ip_info" ]]; then
        ip=$(printf '%s' "$ip_info" | jq -r '.ip // empty' 2>/dev/null || printf '')
        country=$(printf '%s' "$ip_info" | jq -r '.country // empty' 2>/dev/null || printf '')
        city=$(printf '%s' "$ip_info" | jq -r '.city // empty' 2>/dev/null || printf '')
        org=$(printf '%s' "$ip_info" | jq -r '.org // empty' 2>/dev/null || printf '')
    fi

    if [[ -z "$ip" ]]; then
        ip=$(curl -fsSL --max-time 10 "https://ipinfo.io/ip" 2>/dev/null || printf '')
    fi

    jq -n --arg ip "$ip" \
          --arg country "$country" \
          --arg city "$city" \
          --arg organization "$org" \
          --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{ip: $ip, country: $country, city: $city, organization: $organization, timestamp: $timestamp}'
}

run_dns_leak_test() {
    local raw_result
    local timeout_secs="${DNS_LEAK_TIMEOUT:-30}"
    if ! raw_result=$(timeout -k 5 "$timeout_secs" env DNSLEAK_OUTPUT=json bash /expressvpn/dnsleaktest.sh 2>&1); then
        jq -n --arg error "DNS leak test failed" \
              --arg raw "$raw_result" \
              --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{error: $error, raw_output: $raw, timestamp: $timestamp}'
        return
    fi

    local dns_json ip_info conclusion
    dns_json=$(printf '%s' "$raw_result" | jq -c '[.[] | select(.type == "dns") | .ip]')
    ip_info=$(printf '%s' "$raw_result" | jq -c '(.[] | select(.type == "ip")) // {}')
    conclusion=$(printf '%s' "$raw_result" | jq -r '(.[] | select(.type == "conclusion") | .ip) // ""')

    jq -n --argjson dns "$dns_json" \
          --argjson ip "$ip_info" \
          --arg conclusion "$conclusion" \
          --arg raw "$raw_result" \
          --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{dns_servers_found: $dns, ip_info: $ip, conclusion: $conclusion, raw_output: $raw, timestamp: $timestamp}'
}

run_cloudflare_speed_test() {
    local timeout_secs="${CLOUDFLARE_SPEED_TIMEOUT:-120}"
    local output json_output

    if ! command -v cloudflare-speed-cli >/dev/null 2>&1; then
        jq -n --arg error "cloudflare-speed-cli not installed" '{error: $error}'
        return
    fi

    if ! output=$(timeout -k 5 "$timeout_secs" cloudflare-speed-cli --json 2>&1); then
        jq -n --arg error "cloudflare-speed-cli failed" \
              --arg raw "$output" \
              --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{error: $error, raw_output: $raw, timestamp: $timestamp}'
        return
    fi

    printf '%s' "$output" | awk '
        /^Saved:[[:space:]]/ { exit }
        { print }
    '
    return
}

connect_server() {
    local server="$1"
    local output success="false"
    if output=$(expressvpnctl connect "$server" 2>&1); then
        success="true"
    fi

    jq -n --arg success "$success" \
          --arg message "$output" \
          '{success: ($success == "true"), message: $message}'
}

disconnect_vpn() {
    local output success="false"
    if output=$(expressvpnctl disconnect 2>&1); then
        success="true"
    fi

    jq -n --arg success "$success" \
          --arg message "$output" \
          '{success: ($success == "true"), message: $message}'
}

health_status() {
    jq -n --arg status "ok" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        {status: $status, timestamp: $timestamp}'
}

get_vpn_status() {
    local state="stopped"
    local connection_state
    connection_state=$(timeout 3s expressvpnctl get connectionstate 2>/dev/null | trim || true)
    if [[ "$connection_state" == "Connected" ]]; then
        state="running"
    fi
    jq -n --arg status "$state" '{status: $status}'
}

get_vpn_settings() {
    local protocol="" region="" allowlan=""
    protocol=$(timeout 3s expressvpnctl get protocol 2>/dev/null | trim || true)
    region=$(timeout 3s expressvpnctl get region 2>/dev/null | trim || true)
    allowlan=$(timeout 3s expressvpnctl get allowlan 2>/dev/null | trim || true)
    jq -n --arg protocol "$protocol" \
          --arg region "$region" \
          --arg allowlan "$allowlan" \
          '{protocol: $protocol, region: $region, allow_lan: $allowlan}'
}

UPDATE_STATUS_CODE="200 OK"

update_vpn_settings() {
    local body="$1"
    local protocol region allow_lan
    local errors=()
    local applied=()

    UPDATE_STATUS_CODE="200 OK"

    if [[ -z "$body" ]]; then
        UPDATE_STATUS_CODE="400 Bad Request"
        jq -n --arg error "Missing JSON body" '{success: false, error: $error}'
        return
    fi

    protocol=$(printf '%s' "$body" | jq -r '.protocol // empty' 2>/dev/null || printf '')
    region=$(printf '%s' "$body" | jq -r '.region // empty' 2>/dev/null || printf '')
    allow_lan=$(printf '%s' "$body" | jq -r '.allow_lan // empty' 2>/dev/null || printf '')

    if [[ -z "$protocol" && -z "$region" && -z "$allow_lan" ]]; then
        UPDATE_STATUS_CODE="400 Bad Request"
        jq -n --arg error "No supported settings provided" '{success: false, error: $error}'
        return
    fi

    if [[ -n "$protocol" ]]; then
        protocol="${protocol,,}"
        case "$protocol" in
            auto|lightwayudp|lightwaytcp|openvpnudp|openvpntcp|wireguard) ;;
            *)
                UPDATE_STATUS_CODE="400 Bad Request"
                jq -n --arg error "Unsupported protocol: ${protocol}" '{success: false, error: $error}'
                return
                ;;
        esac
        if expressvpnctl set protocol "$protocol" >/dev/null 2>&1; then
            applied+=("protocol")
        else
            errors+=("protocol")
        fi
    fi

    if [[ -n "$region" ]]; then
        if expressvpnctl set region "$region" >/dev/null 2>&1; then
            applied+=("region")
        else
            errors+=("region")
        fi
    fi

    if [[ -n "$allow_lan" ]]; then
        allow_lan="${allow_lan,,}"
        if [[ "$allow_lan" != "true" && "$allow_lan" != "false" ]]; then
            UPDATE_STATUS_CODE="400 Bad Request"
            jq -n --arg error "allow_lan must be true or false" '{success: false, error: $error}'
            return
        fi
        if expressvpnctl set allowlan "$allow_lan" >/dev/null 2>&1; then
            applied+=("allow_lan")
        else
            errors+=("allow_lan")
        fi
    fi

    local errors_json applied_json
    errors_json=$(printf '%s\n' "${errors[@]}" | jq -R -s 'split("\n") | map(select(length>0))')
    applied_json=$(printf '%s\n' "${applied[@]}" | jq -R -s 'split("\n") | map(select(length>0))')

    if ((${#errors[@]} > 0)); then
        UPDATE_STATUS_CODE="500 Internal Server Error"
        jq -n --argjson errors "$errors_json" --argjson applied "$applied_json" \
            '{success: false, errors: $errors, applied: $applied}'
        return
    fi

    jq -n --argjson applied "$applied_json" '{success: true, applied: $applied}'
}

get_public_ip_short() {
    local ip
    ip=$(get_public_ip | jq -r '.ip // empty' 2>/dev/null || printf '')
    jq -n --arg public_ip "$ip" '{public_ip: $public_ip}'
}

get_dns_status() {
    local dns_entries
    dns_entries=$(get_dns_info | jq -r '.dns_servers | length' 2>/dev/null || echo 0)
    if [[ "$dns_entries" -gt 0 ]]; then
        jq -n --arg status "running" '{status: $status}'
    else
        jq -n --arg status "stopped" '{status: $status}'
    fi
}

handle_http_request() {
    local method="$1"
    local full_path="$2"
    local auth_header="$3"
    local api_key_header="$4"
    local body="$5"

    local path="${full_path%%\?*}"
    [[ -z "$path" ]] && path="/"

    if ! check_auth "$auth_header" "$api_key_header" "$method" "$path"; then
        local error_body
        error_body=$(jq -n --arg error "$AUTH_FAILURE_MESSAGE" '{error: $error}')
        http_response "$AUTH_FAILURE_STATUS" "application/json" "$error_body" "$AUTH_FAILURE_HEADER"
        return
    fi

    local method_upper
    method_upper=$(uppercase "$method")

    case "${method_upper} $path" in
        "GET /v1/status")
            http_response "200 OK" "application/json" "$(get_expressvpn_status)"
            ;;
        "GET /v1/vpn/status")
            http_response "200 OK" "application/json" "$(get_vpn_status)"
            ;;
        "GET /v1/vpn/settings")
            http_response "200 OK" "application/json" "$(get_vpn_settings)"
            ;;
        "POST /v1/vpn/settings")
            local update_body
            update_body=$(update_vpn_settings "$body")
            http_response "${UPDATE_STATUS_CODE}" "application/json" "$update_body"
            ;;
        "GET /v1/ip")
            http_response "200 OK" "application/json" "$(get_public_ip)"
            ;;
        "GET /v1/publicip/ip")
            http_response "200 OK" "application/json" "$(get_public_ip_short)"
            ;;
        "GET /v1/dns")
            http_response "200 OK" "application/json" "$(get_dns_info)"
            ;;
        "GET /v1/dns/status")
            http_response "200 OK" "application/json" "$(get_dns_status)"
            ;;
        "GET /v1/dnsleak")
            http_response "200 OK" "application/json" "$(run_dns_leak_test)"
            ;;
        "GET /v1/speedtest")
            http_response "200 OK" "application/json" "$(run_cloudflare_speed_test)"
            ;;
        "GET /v1/servers")
            http_response "200 OK" "application/json" "$(get_servers)"
            ;;
        "GET /v1/health")
            http_response "200 OK" "application/json" "$(health_status)"
            ;;
        "POST /v1/connect")
            local server="smart"
            if [[ -n "$body" ]]; then
                local parsed_server
                parsed_server=$(printf '%s' "$body" | jq -r '.server // empty' 2>/dev/null || printf '')
                if [[ -n "$parsed_server" && "$parsed_server" != "null" ]]; then
                    server="$parsed_server"
                fi
            fi
            http_response "200 OK" "application/json" "$(connect_server "$server")"
            ;;
        "POST /v1/disconnect")
            http_response "200 OK" "application/json" "$(disconnect_vpn)"
            ;;
        *)
            local error_body
            error_body=$(jq -n --arg error "Endpoint not found" '{error: $error}')
            http_response "404 Not Found" "application/json" "$error_body"
            ;;
    esac
}

handle_connection() {
    local request_line method path version header_line auth_header="" api_key_header="" content_length=0 body=""

    if ! IFS= read -r request_line; then
        return
    fi
    request_line=${request_line%$'\r'}
    log "Incoming request: $request_line"

    IFS=' ' read -r method path version <<< "$request_line"

    while IFS= read -r header_line; do
        header_line=${header_line%$'\r'}
        [[ -z "$header_line" ]] && break
        case "$header_line" in
            [Aa]uthorization:*)
                auth_header="$header_line"
                ;;
            [Xx]-[Aa][Pp][Ii]-[Kk]ey:*)
                api_key_header="$header_line"
                ;;
            [Cc]ontent-[Ll]ength:*)
                content_length=$(printf '%s' "$header_line" | awk -F': *' 'tolower($1)=="content-length"{print $2}' | tr -d $'\r\n')
                ;;
        esac
    done

    content_length=${content_length:-0}

    if (( content_length > 0 )); then
        body=$(dd bs=1 count="$content_length" 2>/dev/null || printf '')
    fi

    local response
    response=$(handle_http_request "${method:-}" "${path:-/}" "$auth_header" "$api_key_header" "$body")
    printf '%s' "$response"
}

start_server() {
    log "Starting ExpressVPN control server on $CONTROL_IP:$CONTROL_PORT"

    local exec_cmd
    printf -v exec_cmd 'env AUTH_CONFIG=%q CONTROL_PORT=%q CONTROL_IP=%q /expressvpn/control-server.sh --handle' \
        "$AUTH_CONFIG" "$CONTROL_PORT" "$CONTROL_IP"

    local listen_addr="TCP-LISTEN:${CONTROL_PORT},reuseaddr,fork"
    if [[ "$CONTROL_IP" != "0.0.0.0" ]]; then
        listen_addr+=",bind=${CONTROL_IP}"
    fi

    while true; do
        if ! socat -T30 "${listen_addr}" EXEC:"${exec_cmd}",pipes >/dev/null 2>&1; then
            log "socat terminated with error, retrying in 1s"
            sleep 1
        fi
    done
}

if [[ "${1:-}" == "--handle" ]]; then
    handle_connection
    exit 0
fi

trap 'log "Shutting down control server"; exit 0' INT TERM

start_server
