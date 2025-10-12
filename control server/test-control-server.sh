#!/bin/bash
set -euo pipefail

# Test script for ExpressVPN Control Server
# This script demonstrates how to use the control server API

CONTROL_SERVER_URL="${CONTROL_SERVER_URL:-http://localhost:8000}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-changeme}"
API_KEY="${API_KEY:-}"
AUTH_TYPE="${AUTH_TYPE:-basic}"

log() {
    echo "[test] $*"
}

test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local expected_status="${4:-200}"
    
    log "Testing $method $endpoint"
    
    local curl_args=("-s" "-w" "%{http_code}")
    
    # Add authentication based on type
    case "$AUTH_TYPE" in
        "basic")
            curl_args+=("-u" "$USERNAME:$PASSWORD")
            ;;
        "api_key")
            if [[ -n "$API_KEY" ]]; then
                curl_args+=("-H" "Authorization: Bearer $API_KEY")
            else
                log "✗ API_KEY not set for api_key authentication"
                return 1
            fi
            ;;
        "none")
            # No authentication headers needed
            ;;
        *)
            log "✗ Unknown auth type: $AUTH_TYPE"
            return 1
            ;;
    esac
    
    if [[ "$method" == "POST" ]]; then
        curl_args+=("-X" "POST" "-H" "Content-Type: application/json" "-d" "$data")
    fi
    
    local response
    response=$(curl "${curl_args[@]}" "$CONTROL_SERVER_URL$endpoint" 2>/dev/null || echo "000")
    
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$status_code" == "$expected_status" ]]; then
        log "✓ $method $endpoint - Status: $status_code"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        log "✗ $method $endpoint - Expected: $expected_status, Got: $status_code"
        echo "$body"
    fi
    
    echo
}

main() {
    log "Testing ExpressVPN Control Server at $CONTROL_SERVER_URL"
    case "$AUTH_TYPE" in
        "basic")
            log "Using basic authentication: $USERNAME:***"
            ;;
        "api_key")
            log "Using API key authentication: ${API_KEY:0:8}***"
            ;;
        "none")
            log "Using no authentication"
            ;;
    esac
    echo
    
    # Test health endpoint
    test_endpoint "GET" "/v1/health"
    
    # Test status endpoint
    test_endpoint "GET" "/v1/status"
    
    # Test servers endpoint
    test_endpoint "GET" "/v1/servers"
    
    # Test DNS information endpoint
    test_endpoint "GET" "/v1/dns"
    
    # Test public IP endpoint
    test_endpoint "GET" "/v1/ip"
    
    # Test DNS leak test endpoint
    test_endpoint "GET" "/v1/dnsleak"
    
    # Test connect endpoint (this will fail if not authenticated properly)
    test_endpoint "POST" "/v1/connect" '{"server": "smart"}' "200"
    
    # Test disconnect endpoint
    test_endpoint "POST" "/v1/disconnect"
    
    log "Control server test completed"
}

main "$@"
