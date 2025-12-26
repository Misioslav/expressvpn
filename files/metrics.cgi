#!/bin/bash
set -euo pipefail

# CGI header for busybox httpd
echo "Content-Type: text/plain; version=0.0.4"
echo

# Helpers
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# 1) Determine connection status and settings via expressvpnctl (best effort)
connected=0
connection_state=""
server_label=""
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

# Prefer the actual connected location from status; fall back to configured region.
status_output=$(timeout 3s expressvpnctl status 2>/dev/null || true)
server_label=$(printf '%s\n' "$status_output" | sed -n 's/^Connected to[: ]\{1,\}//p' | head -n1 | trim || true)
if [[ -z "$server_label" ]]; then
  server_label=$(timeout 3s expressvpnctl get region 2>/dev/null | trim || true)
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
# info metric with labels (strings go in labels)
printf 'expressvpn_connection_info{server="%s",protocol="%s",network_lock="%s"} 1\n' \
  "${server_label//\"/\\\"}" "${protocol_label//\"/\\\"}" "${network_lock_label//\"/\\\"}"
printf 'expressvpn_vpn_ip_info{ip="%s"} 1\n' "${vpn_ip_label//\"/\\\"}"
printf 'expressvpn_public_ip_info{ip="%s"} 1\n' "${public_ip_label//\"/\\\"}"

# Interface metrics (only if detected)
if [[ -n "$vpn_if" && -d "/sys/class/net/$vpn_if/statistics" ]]; then
  rx_bytes=$(cat "/sys/class/net/$vpn_if/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx_bytes=$(cat "/sys/class/net/$vpn_if/statistics/tx_bytes" 2>/dev/null || echo 0)
  rx_pkts=$(cat "/sys/class/net/$vpn_if/statistics/rx_packets" 2>/dev/null || echo 0)
  tx_pkts=$(cat "/sys/class/net/$vpn_if/statistics/tx_packets" 2>/dev/null || echo 0)

  printf 'expressvpn_vpn_interface_info{interface="%s"} 1\n' "${vpn_if}"

  printf 'expressvpn_network_rx_bytes_total{interface="%s"} %s\n' "${vpn_if}" "${rx_bytes}"
  printf 'expressvpn_network_tx_bytes_total{interface="%s"} %s\n' "${vpn_if}" "${tx_bytes}"
  printf 'expressvpn_network_rx_packets_total{interface="%s"} %s\n' "${vpn_if}" "${rx_pkts}"
  printf 'expressvpn_network_tx_packets_total{interface="%s"} %s\n' "${vpn_if}" "${tx_pkts}"
else
  echo 'expressvpn_vpn_interface_info{interface=""} 0'
fi
