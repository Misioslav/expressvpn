#!/bin/bash
set -euo pipefail

resolve_check_ip() {
    if [[ -n ${DDNS:-} ]]; then
        local resolved
        resolved=$(getent ahostsv4 "$DDNS" 2>/dev/null | awk 'NR==1 { print $1 }') || true
        if [[ -z $resolved ]]; then
            # Fallback to any family (likely IPv6) so we still perform the check
            resolved=$(getent hosts "$DDNS" 2>/dev/null | awk 'NR==1 { print $1 }') || true
        fi
        [[ -n $resolved ]] && echo "$resolved"
        return
    fi

    if [[ -n ${IP:-} ]]; then
        echo "$IP"
    fi
}

notify_healthcheck() {
    local suffix="$1"
    [[ -z ${HEALTHCHECK:-} ]] && return

    curl -fsS --max-time 10 "https://hc-ping.com/${HEALTHCHECK}${suffix}"
}

main() {
    local target_ip
    target_ip=$(resolve_check_ip || true)

    [[ -z $target_ip ]] && exit 0

    local express_ip
    if ! express_ip=$(curl -fsSL --max-time 10 -H "Authorization: Bearer ${BEARER:-}" "https://ipinfo.io" | jq -r '.ip'); then
        notify_healthcheck "/fail" || true
        exit 1
    fi

    if [[ -z $express_ip || $express_ip == "null" ]]; then
        notify_healthcheck "/fail" || true
        exit 1
    fi

    if [[ "$target_ip" == "$express_ip" ]]; then
        notify_healthcheck "/fail" || true
        expressvpn disconnect || true
        expressvpn connect "${SERVER:-smart}" || true
        exit 1
    fi

    notify_healthcheck "" || true
    exit 0
}

main
