#!/bin/bash
set -euo pipefail

API_DOMAIN="bash.ws"

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$cmd" >&2
        exit 1
    fi
}

require_cmd curl
require_cmd ping

if ! curl --silent --head "https://${API_DOMAIN}" | grep -q "200 OK"; then
    printf 'No internet connection or unable to reach %s\n' "$API_DOMAIN" >&2
    exit 1
fi

id=$(curl --silent "https://${API_DOMAIN}/id")

for i in $(seq 1 10); do
    ping -c 1 -W 1 "${i}.${id}.${API_DOMAIN}" >/dev/null 2>&1 || true
done

curl --silent "https://${API_DOMAIN}/dnsleak/test/${id}?json"
