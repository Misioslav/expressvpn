#!/bin/bash
set -euo pipefail

# Demo script for new ExpressVPN Control Server endpoints
# This script demonstrates the DNS, IP, and DNS leak test functionality

CONTROL_SERVER_URL="${CONTROL_SERVER_URL:-http://localhost:8000}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-changeme}"
API_KEY="${API_KEY:-}"
AUTH_TYPE="${AUTH_TYPE:-basic}"

log() {
    echo "[demo] $*"
}

demo_endpoint() {
    local endpoint="$1"
    local description="$2"
    
    log "=== $description ==="
    echo "Endpoint: GET $endpoint"
    
    # Build curl command based on auth type
    local curl_cmd="curl"
    case "$AUTH_TYPE" in
        "basic")
            curl_cmd="curl -u $USERNAME:***"
            ;;
        "api_key")
            curl_cmd="curl -H \"Authorization: Bearer ${API_KEY:0:8}***\""
            ;;
        "none")
            curl_cmd="curl"
            ;;
    esac
    echo "Command: $curl_cmd $CONTROL_SERVER_URL$endpoint"
    echo
    
    # Build actual curl command
    local curl_args=("-s")
    case "$AUTH_TYPE" in
        "basic")
            curl_args+=("-u" "$USERNAME:$PASSWORD")
            ;;
        "api_key")
            if [[ -n "$API_KEY" ]]; then
                curl_args+=("-H" "Authorization: Bearer $API_KEY")
            fi
            ;;
        "none")
            # No authentication headers needed
            ;;
    esac
    
    local response
    response=$(curl "${curl_args[@]}" "$CONTROL_SERVER_URL$endpoint" 2>/dev/null || echo '{"error": "Failed to connect"}')
    
    echo "Response:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo
    echo "---"
    echo
}

main() {
    log "ExpressVPN Control Server - New Endpoints Demo"
    log "Server: $CONTROL_SERVER_URL"
    case "$AUTH_TYPE" in
        "basic")
            log "Authentication: Basic ($USERNAME)"
            ;;
        "api_key")
            log "Authentication: API Key (${API_KEY:0:8}***)"
            ;;
        "none")
            log "Authentication: None"
            ;;
    esac
    echo
    
    # Demo DNS information endpoint
    demo_endpoint "/v1/dns" "DNS Configuration Information"
    
    # Demo public IP endpoint
    demo_endpoint "/v1/ip" "Public IP and Location Information"
    
    # Demo DNS leak test endpoint
    demo_endpoint "/v1/dnsleak" "DNS Leak Test Results"
    
    log "Demo completed!"
    log ""
    log "These endpoints provide:"
    log "• DNS servers currently in use by the container"
    log "• Public IP address and geographic location"
    log "• DNS leak test results using macvk/dnsleaktest"
    log ""
    log "Use these endpoints to monitor VPN connection quality and security."
}

main "$@"
