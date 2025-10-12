#!/bin/bash
set -euo pipefail

resolve_check_ip() {
    if [[ -n ${DDNS:-} ]]; then
        local -a resolved=()
        local -A seen=()
        # Collect IPv4 entries first to match the IPv4-only ExpressVPN lookup
        while IFS= read -r ip; do
            if [[ -n $ip && -z ${seen["$ip"]:-} ]]; then
                resolved+=("$ip")
                seen["$ip"]=1
            fi
        done < <(getent ahostsv4 "$DDNS" 2>/dev/null | awk '{ print $1 }' || true)

        if [[ ${#resolved[@]} -eq 0 ]]; then
            # Fallback to any family (likely IPv6) so we still perform the check
            while IFS= read -r ip; do
                if [[ -n $ip && -z ${seen["$ip"]:-} ]]; then
                    resolved+=("$ip")
                    seen["$ip"]=1
                fi
            done < <(getent hosts "$DDNS" 2>/dev/null | awk '{ print $1 }' || true)
        fi

        if [[ ${#resolved[@]} -gt 0 ]]; then
            printf '%s\n' "${resolved[@]}"
        fi
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
    local -a target_ips=()
    while IFS= read -r ip; do
        [[ -n $ip ]] && target_ips+=("$ip")
    done < <(resolve_check_ip || true)

    [[ ${#target_ips[@]} -eq 0 ]] && exit 0

    local express_ip
    if ! express_ip=$(curl -fsSL --max-time 10 -H "Authorization: Bearer ${BEARER:-}" "https://ipinfo.io" | jq -r '.ip'); then
        notify_healthcheck "/fail" || true
        exit 1
    fi

    if [[ -z $express_ip || $express_ip == "null" ]]; then
        notify_healthcheck "/fail" || true
        exit 1
    fi

    local match=false
    for ip in "${target_ips[@]}"; do
        if [[ "$ip" == "$express_ip" ]]; then
            match=true
            break
        fi
    done

    if [[ $match == true ]]; then
        notify_healthcheck "/fail" || true
        expressvpn disconnect || true
        expressvpn connect "${SERVER:-smart}" || true
        exit 1
    fi

    notify_healthcheck "" || true
    exit 0
}

main
