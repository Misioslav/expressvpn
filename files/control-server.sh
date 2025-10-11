#!/bin/bash
set -euo pipefail

# ExpressVPN Control Server
# HTTP API for controlling ExpressVPN container

CONTROL_PORT="${CONTROL_PORT:-8000}"
CONTROL_IP="${CONTROL_IP:-0.0.0.0}"
AUTH_CONFIG="${AUTH_CONFIG:-/expressvpn/config.toml}"

log() {
    echo "[control-server] $*" >&2
}

# Simple HTTP response function
http_response() {
    local status_code="$1"
    local content_type="${2:-application/json}"
    local body="$3"
    
    echo -e "HTTP/1.1 $status_code\r
Content-Type: $content_type\r
Content-Length: ${#body}\r
Connection: close\r
\r
$body"
}

# Parse HTTP request
parse_request() {
    local line
    read -r line
    local method path version
    read -r method path version <<< "$line"
    
    # Read headers
    local headers=()
    while read -r line && [[ -n "$line" ]]; do
        headers+=("$line")
    done
    
    echo "$method|$path|${headers[*]}"
}

# Authentication check
check_auth() {
    local auth_header="$1"
    local method="$2"
    local path="$3"
    
    # If no auth config, allow all (for backward compatibility)
    [[ ! -f "$AUTH_CONFIG" ]] && return 0
    
    # Check for "none" authentication (explicitly disabled)
    local auth_type
    auth_type=$(grep -E '^\s*auth\s*=' "$AUTH_CONFIG" | sed 's/.*=\s*"\([^"]*\)".*/\1/' || true)
    
    if [[ "$auth_type" == "none" ]]; then
        return 0
    fi
    
    # Check for API key authentication
    if [[ "$auth_type" == "api_key" ]]; then
        local api_key
        api_key=$(echo "$auth_header" | sed -n 's/.*Authorization: Bearer \([^[:space:]]*\).*/\1/p' || true)
        
        if [[ -z "$api_key" ]]; then
            return 1
        fi
        
        local config_api_key
        config_api_key=$(grep -E '^\s*api_key\s*=' "$AUTH_CONFIG" | sed 's/.*=\s*"\([^"]*\)".*/\1/' || true)
        
        if [[ "$api_key" == "$config_api_key" ]]; then
            return 0
        fi
        
        return 1
    fi
    
    # Default to basic authentication
    if [[ "$auth_type" == "basic" || -z "$auth_type" ]]; then
        # Extract username:password from Authorization header
        local auth_string
        auth_string=$(echo "$auth_header" | sed -n 's/.*Authorization: Basic \([^[:space:]]*\).*/\1/p' | base64 -d 2>/dev/null || true)
        
        if [[ -z "$auth_string" ]]; then
            return 1
        fi
        
        local username password
        IFS=':' read -r username password <<< "$auth_string"
        
        # Simple config parsing (basic TOML-like format)
        local config_username config_password
        config_username=$(grep -E '^\s*username\s*=' "$AUTH_CONFIG" | sed 's/.*=\s*"\([^"]*\)".*/\1/' || true)
        config_password=$(grep -E '^\s*password\s*=' "$AUTH_CONFIG" | sed 's/.*=\s*"\([^"]*\)".*/\1/' || true)
        
        if [[ "$username" == "$config_username" && "$password" == "$config_password" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Get ExpressVPN status
get_expressvpn_status() {
    local status
    if status=$(expressvpn status 2>/dev/null); then
        local connected=false
        local server=""
        local ip=""
        
        if echo "$status" | grep -q "Connected to"; then
            connected=true
            server=$(echo "$status" | grep "Connected to" | sed 's/.*Connected to \([^[:space:]]*\).*/\1/')
            ip=$(echo "$status" | grep "Your new IP" | sed 's/.*Your new IP is \([^[:space:]]*\).*/\1/')
        fi
        
        cat << EOF
{
  "connected": $connected,
  "server": "$server",
  "ip": "$ip",
  "status": "$status"
}
EOF
    else
        cat << EOF
{
  "connected": false,
  "server": "",
  "ip": "",
  "status": "ExpressVPN not running"
}
EOF
    fi
}

# Get available servers
get_servers() {
    local servers
    if servers=$(expressvpn list all 2>/dev/null); then
        # Convert to JSON format
        echo "$servers" | awk '
        BEGIN { print "[" }
        /^[A-Z]/ { 
            if (NR > 1) print ","
            gsub(/"/, "\\\"")
            print "  \"" $0 "\""
        }
        END { print "]" }
        '
    else
        echo '[]'
    fi
}

# Get DNS information
get_dns_info() {
    local dns_servers=()
    local resolv_conf="/etc/resolv.conf"
    
    # Read DNS servers from resolv.conf
    if [[ -f "$resolv_conf" ]]; then
        while read -r line; do
            if [[ "$line" =~ ^nameserver[[:space:]]+([^[:space:]]+) ]]; then
                dns_servers+=("${BASH_REMATCH[1]}")
            fi
        done < "$resolv_conf"
    fi
    
    # Convert to JSON
    local json_dns="["
    for i in "${!dns_servers[@]}"; do
        [[ $i -gt 0 ]] && json_dns+=","
        json_dns+="\"${dns_servers[$i]}\""
    done
    json_dns+="]"
    
    cat << EOF
{
  "dns_servers": $json_dns,
  "resolv_conf": "$(cat "$resolv_conf" 2>/dev/null | tr '\n' ';' | sed 's/;$/\\n/')"
}
EOF
}

# Get public IP information
get_public_ip() {
    local ip_info
    local ip=""
    local country=""
    local city=""
    local org=""
    
    # Try to get IP info with bearer token if available
    if [[ -n "${BEARER:-}" ]]; then
        if ip_info=$(curl -fsSL --max-time 10 -H "Authorization: Bearer ${BEARER}" "https://ipinfo.io" 2>/dev/null); then
            ip=$(echo "$ip_info" | jq -r '.ip // empty' 2>/dev/null)
            country=$(echo "$ip_info" | jq -r '.country // empty' 2>/dev/null)
            city=$(echo "$ip_info" | jq -r '.city // empty' 2>/dev/null)
            org=$(echo "$ip_info" | jq -r '.org // empty' 2>/dev/null)
        fi
    fi
    
    # Fallback to simple IP check if no bearer token or if it failed
    if [[ -z "$ip" || "$ip" == "null" ]]; then
        ip=$(curl -fsSL --max-time 10 "https://ipinfo.io/ip" 2>/dev/null || echo "")
    fi
    
    cat << EOF
{
  "ip": "$ip",
  "country": "$country",
  "city": "$city",
  "organization": "$org",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Run DNS leak test
run_dns_leak_test() {
    local test_result
    local temp_file="/tmp/dnsleaktest_result"
    
    # Run the DNS leak test and capture output
    if test_result=$(curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/refs/heads/master/dnsleaktest.sh | bash -s 2>&1); then
        # Parse the results
        local dns_servers=()
        local test_summary=""
        
        # Extract DNS servers found
        while IFS= read -r line; do
            if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                dns_servers+=("$line")
            elif [[ "$line" =~ ^[A-Za-z] ]]; then
                test_summary="$line"
            fi
        done <<< "$test_result"
        
        # Convert to JSON
        local json_dns="["
        for i in "${!dns_servers[@]}"; do
            [[ $i -gt 0 ]] && json_dns+=","
            json_dns+="\"${dns_servers[$i]}\""
        done
        json_dns+="]"
        
        cat << EOF
{
  "dns_servers_found": $json_dns,
  "test_summary": "$test_summary",
  "raw_output": "$(echo "$test_result" | tr '\n' ';' | sed 's/;$/\\n/')",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    else
        cat << EOF
{
  "error": "DNS leak test failed",
  "raw_output": "$(echo "$test_result" | tr '\n' ';' | sed 's/;$/\\n/')",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    fi
}

# Connect to server
connect_server() {
    local server="$1"
    
    if expressvpn connect "$server" 2>/dev/null; then
        cat << EOF
{
  "success": true,
  "message": "Connected to $server"
}
EOF
    else
        cat << EOF
{
  "success": false,
  "message": "Failed to connect to $server"
}
EOF
    fi
}

# Disconnect
disconnect_vpn() {
    if expressvpn disconnect 2>/dev/null; then
        cat << EOF
{
  "success": true,
  "message": "Disconnected successfully"
}
EOF
    else
        cat << EOF
{
  "success": false,
  "message": "Failed to disconnect"
}
EOF
    fi
}

# Handle HTTP request
handle_request() {
    local request_info="$1"
    local method path headers
    IFS='|' read -r method path headers <<< "$request_info"
    
    # Extract Authorization header
    local auth_header=""
    for header in $headers; do
        if [[ "$header" =~ ^Authorization: ]]; then
            auth_header="$header"
            break
        fi
    done
    
    # Check authentication
    if ! check_auth "$auth_header" "$method" "$path"; then
        http_response "401 Unauthorized" "application/json" '{"error": "Authentication required"}'
        return
    fi
    
    # Route requests
    case "$method $path" in
        "GET /v1/status")
            http_response "200 OK" "application/json" "$(get_expressvpn_status)"
            ;;
        "GET /v1/servers")
            http_response "200 OK" "application/json" "$(get_servers)"
            ;;
        "GET /v1/dns")
            http_response "200 OK" "application/json" "$(get_dns_info)"
            ;;
        "GET /v1/ip")
            http_response "200 OK" "application/json" "$(get_public_ip)"
            ;;
        "GET /v1/dnsleak")
            http_response "200 OK" "application/json" "$(run_dns_leak_test)"
            ;;
        "POST /v1/connect")
            # Read POST body
            local body=""
            read -r body
            local server
            server=$(echo "$body" | jq -r '.server // empty' 2>/dev/null || echo "")
            if [[ -z "$server" ]]; then
                http_response "400 Bad Request" "application/json" '{"error": "Server parameter required"}'
            else
                http_response "200 OK" "application/json" "$(connect_server "$server")"
            fi
            ;;
        "POST /v1/disconnect")
            http_response "200 OK" "application/json" "$(disconnect_vpn)"
            ;;
        "GET /v1/health")
            http_response "200 OK" "application/json" '{"status": "healthy"}'
            ;;
        *)
            http_response "404 Not Found" "application/json" '{"error": "Endpoint not found"}'
            ;;
    esac
}

# Main server loop
main() {
    log "Starting ExpressVPN control server on $CONTROL_IP:$CONTROL_PORT"
    
    # Start netcat server with proper error handling
    while true; do
        if ! nc -l -p "$CONTROL_PORT" -k 2>/dev/null | while read -r line; do
            if [[ -n "$line" ]]; then
                local request_info
                if request_info=$(parse_request 2>/dev/null); then
                    handle_request "$request_info"
                fi
            fi
        done; then
            log "Control server connection closed, restarting..."
            sleep 1
        else
            log "Control server error, restarting..."
            sleep 5
        fi
    done
}

# Handle signals
trap 'log "Shutting down control server"; exit 0' INT TERM

main "$@"
