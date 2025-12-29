#!/bin/bash
set -euo pipefail

# CGI header for busybox httpd
echo "Content-Type: text/plain; version=0.0.4"
echo

# Helpers
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# Simple state tracking to support counters across scrapes.
state_file="/tmp/expressvpn-metrics.state"
state_lock="/tmp/expressvpn-metrics.lock"

last_state=""
last_state_ts=0
connected_since=0
connect_attempts=0
connect_failures=0
state_changes=0

state_update=false
if mkdir "${state_lock}" 2>/dev/null; then
  state_update=true
  trap 'rmdir "${state_lock}"' EXIT
fi

if [[ -f "${state_file}" ]]; then
  while IFS='=' read -r key value; do
    case "$key" in
      last_state) last_state="$value" ;;
      last_state_ts) last_state_ts="$value" ;;
      connected_since) connected_since="$value" ;;
      connect_attempts) connect_attempts="$value" ;;
      connect_failures) connect_failures="$value" ;;
      state_changes) state_changes="$value" ;;
    esac
  done < "${state_file}"
fi

# 1) Determine connection status and settings via expressvpnctl (best effort)
connected=0
connection_state=""
server_label=""
connected_server_label=""
protocol_label=""
network_lock_label=""
vpn_ip_label=""
public_ip_label=""

state_label=$(timeout 3s expressvpnctl get connectionstate 2>/dev/null | trim || true)
case "$state_label" in
  Connected) connected=1 ;;
  Disconnected|Connecting|Interrupted|Reconnecting|DisconnectingToReconnect|Disconnecting) ;;
  *) ;;
esac
connection_state="$state_label"

# 2) Determine preferences via expressvpnctl (best effort)
protocol_label=$(timeout 3s expressvpnctl get protocol 2>/dev/null | trim || true)
network_lock_label=$(timeout 3s expressvpnctl get networklock 2>/dev/null | trim || true)
vpn_ip_label=$(timeout 3s expressvpnctl get vpnip 2>/dev/null | trim || true)
public_ip_label=$(timeout 3s expressvpnctl get pubip 2>/dev/null | trim || true)

# Capture configured region and actual connected server (if any).
server_label=$(timeout 3s expressvpnctl get region 2>/dev/null | trim || true)
status_output=$(timeout 3s expressvpnctl status 2>/dev/null || true)
connected_server_label=$(printf '%s\n' "$status_output" | sed -n 's/^Connected to[: ]\{1,\}//p' | head -n1 | trim || true)
if [[ -z "$connected_server_label" ]]; then
  connected_server_label="$server_label"
fi

# 2b) Update stateful counters and timestamps
now_ts=$(date +%s)
if [[ -n "$connection_state" ]]; then
  if [[ "$connection_state" != "$last_state" ]]; then
    state_changes=$((state_changes + 1))
    last_state_ts="${now_ts}"
  fi

  if [[ "$connection_state" == "Connected" ]]; then
    if [[ "$last_state" != "Connected" ]]; then
      connected_since="${now_ts}"
    fi
  elif [[ "$last_state" == "Connected" ]]; then
    connected_since=0
  fi

  if [[ "$connection_state" =~ ^(Connecting|Reconnecting|DisconnectingToReconnect)$ ]] \
    && [[ "$last_state" != "$connection_state" ]]; then
    connect_attempts=$((connect_attempts + 1))
  fi

  if [[ "$last_state" =~ ^(Connecting|Reconnecting|DisconnectingToReconnect)$ ]] \
    && [[ "$connection_state" =~ ^(Disconnected|Interrupted)$ ]]; then
    connect_failures=$((connect_failures + 1))
  fi

  last_state="$connection_state"
fi

connection_uptime=0
if [[ ${connected} -eq 1 && ${connected_since} -gt 0 ]]; then
  connection_uptime=$((now_ts - connected_since))
fi

if [[ "$state_update" == "true" ]]; then
  {
    echo "last_state=${last_state}"
    echo "last_state_ts=${last_state_ts}"
    echo "connected_since=${connected_since}"
    echo "connect_attempts=${connect_attempts}"
    echo "connect_failures=${connect_failures}"
    echo "state_changes=${state_changes}"
  } > "${state_file}"
fi

# Fallbacks to env if not detectable
: "${protocol_label:=${PROTOCOL:-}}"
: "${network_lock_label:=}"

# 3) Detect VPN interface (default to tun0, else first tun*)
vpn_if="${METRICS_VPN_IF:-}"
if [[ -z "$vpn_if" ]]; then
  if [[ -d /sys/class/net/tun0 ]]; then
    vpn_if="tun0"
  else
    vpn_if=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2; exit}' || true)
  fi
fi

# 4) Emit metrics
# Connection metrics
echo "expressvpn_connection_status ${connected}"
# Connection state metric (label enum)
printf 'expressvpn_connection_state{state="%s"} 1\n' "${connection_state//\"/\\\"}"
printf 'expressvpn_connection_uptime_seconds %s\n' "${connection_uptime}"
printf 'expressvpn_last_state_change_timestamp_seconds %s\n' "${last_state_ts}"
printf 'expressvpn_state_changes_total %s\n' "${state_changes}"
printf 'expressvpn_connect_attempts_total %s\n' "${connect_attempts}"
printf 'expressvpn_connect_failures_total %s\n' "${connect_failures}"
# info metric with labels (strings go in labels)
printf 'expressvpn_connection_info{server="%s",connected_server="%s",protocol="%s",network_lock="%s"} 1\n' \
  "${server_label//\"/\\\"}" "${connected_server_label//\"/\\\"}" "${protocol_label//\"/\\\"}" "${network_lock_label//\"/\\\"}"
printf 'expressvpn_vpn_ip_info{ip="%s"} 1\n' "${vpn_ip_label//\"/\\\"}"
printf 'expressvpn_public_ip_info{ip="%s"} 1\n' "${public_ip_label//\"/\\\"}"

# Interface metrics (only if detected)
if [[ -n "$vpn_if" && -d "/sys/class/net/$vpn_if/statistics" ]]; then
  rx_bytes=$(cat "/sys/class/net/$vpn_if/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx_bytes=$(cat "/sys/class/net/$vpn_if/statistics/tx_bytes" 2>/dev/null || echo 0)
  rx_pkts=$(cat "/sys/class/net/$vpn_if/statistics/rx_packets" 2>/dev/null || echo 0)
  tx_pkts=$(cat "/sys/class/net/$vpn_if/statistics/tx_packets" 2>/dev/null || echo 0)
  rx_errors=$(cat "/sys/class/net/$vpn_if/statistics/rx_errors" 2>/dev/null || echo 0)
  tx_errors=$(cat "/sys/class/net/$vpn_if/statistics/tx_errors" 2>/dev/null || echo 0)
  rx_dropped=$(cat "/sys/class/net/$vpn_if/statistics/rx_dropped" 2>/dev/null || echo 0)
  tx_dropped=$(cat "/sys/class/net/$vpn_if/statistics/tx_dropped" 2>/dev/null || echo 0)
  mtu=$(cat "/sys/class/net/$vpn_if/mtu" 2>/dev/null || echo 0)
  operstate=$(cat "/sys/class/net/$vpn_if/operstate" 2>/dev/null || echo "")
  vpn_if_up=0
  if [[ "$operstate" == "up" ]]; then
    vpn_if_up=1
  fi

  printf 'expressvpn_vpn_interface_info{interface="%s"} 1\n' "${vpn_if}"
  printf 'expressvpn_vpn_interface_up{interface="%s"} %s\n' "${vpn_if}" "${vpn_if_up}"
  printf 'expressvpn_vpn_interface_mtu_bytes{interface="%s"} %s\n' "${vpn_if}" "${mtu}"

  printf 'expressvpn_network_rx_bytes_total{interface="%s"} %s\n' "${vpn_if}" "${rx_bytes}"
  printf 'expressvpn_network_tx_bytes_total{interface="%s"} %s\n' "${vpn_if}" "${tx_bytes}"
  printf 'expressvpn_network_rx_packets_total{interface="%s"} %s\n' "${vpn_if}" "${rx_pkts}"
  printf 'expressvpn_network_tx_packets_total{interface="%s"} %s\n' "${vpn_if}" "${tx_pkts}"
  printf 'expressvpn_network_rx_errors_total{interface="%s"} %s\n' "${vpn_if}" "${rx_errors}"
  printf 'expressvpn_network_tx_errors_total{interface="%s"} %s\n' "${vpn_if}" "${tx_errors}"
  printf 'expressvpn_network_rx_dropped_total{interface="%s"} %s\n' "${vpn_if}" "${rx_dropped}"
  printf 'expressvpn_network_tx_dropped_total{interface="%s"} %s\n' "${vpn_if}" "${tx_dropped}"
else
  echo 'expressvpn_vpn_interface_info{interface=""} 0'
  echo 'expressvpn_vpn_interface_up{interface=""} 0'
  echo 'expressvpn_vpn_interface_mtu_bytes{interface=""} 0'
fi
