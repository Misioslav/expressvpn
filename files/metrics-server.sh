#!/bin/bash
set -euo pipefail

EXPECTED_PATH="${METRICS_EXPECTED_PATH:-/metrics.cgi}"

read_request_line() {
    local line
    if ! IFS= read -r line; then
        echo ""
        return 1
    fi
    echo "${line%$'\r'}"
    return 0
}

send_response() {
    local status="$1"
    local content_type="$2"
    local body="$3"
    local length
    length=$(printf '%s' "$body" | LC_ALL=C wc -c | tr -d ' ')
    printf 'HTTP/1.1 %s\r\n' "$status"
    printf 'Content-Type: %s\r\n' "$content_type"
    printf 'Content-Length: %s\r\n' "$length"
    printf 'Connection: close\r\n'
    printf '\r\n%s' "$body"
}

main() {
    local request_line method path version header

    request_line=$(read_request_line) || exit 0
    IFS=' ' read -r method path version <<< "${request_line:-GET / HTTP/1.1}"

    # Consume headers
    while IFS= read -r header; do
        header=${header%$'\r'}
        [[ -z "$header" ]] && break
    done

    if [[ "${method^^}" != "GET" ]]; then
        send_response "405 Method Not Allowed" "text/plain" "method not allowed"
        exit 0
    fi

    if [[ "$path" != "$EXPECTED_PATH" && "$path" != "/metrics" ]]; then
        send_response "404 Not Found" "text/plain" "not found"
        exit 0
    fi

    local metrics
    if ! metrics=$(/expressvpn/metrics.cgi 2>/dev/null | sed '1,2d'); then
        send_response "500 Internal Server Error" "text/plain" "failed to generate metrics"
        exit 0
    fi

    send_response "200 OK" "text/plain; version=0.0.4" "$metrics"
}

main "$@"
