#!/bin/bash
set -euo pipefail

# CGI header for busybox httpd
echo "Content-Type: text/plain; version=0.0.4"
echo

# Helpers
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# 1) Determine connection status and server via expressvpn status
connected=0
server_label=""
protocol_label=""
cipher_label=""
network_lock_label=""

# Use fast timeouts so scrape never hangs
if status_out=$(timeout 4s expressvpn status 2>/dev/null || true); then
  # Examples to consider (best-effort parsing):
  # "Connected to <server/location> [protocol]."
  # "Not connected."
  # "Connecting to ..."
  if grep -qi "connected to" <<<"$status_out"; then
    connected=1
    # Extract substring after "Connected to " up to first punctuation or end
    server_label=$(grep -i "connected to" <<<"$status_out" | head -n1 | sed -E 's/.*[Cc]onnected to[[:space:]]+([^.,]+).*/\1/' | trim)
  fi
fi

# 2) Determine preferences: protocol, cipher, network_lock (best effort)
if pref_out=$(timeout 3s expressvpn preferences 2>/dev/null || true); then
  protocol_label=$(grep -i '^preferred_protocol:' <<<"$pref_out" | awk -F: '{print $2}' | trim || true)
  cipher_label=$(grep -i '^lightway_cipher:' <<<"$pref_out" | awk -F: '{print $2}' | trim || true)
  network_lock_label=$(grep -i '^network_lock:' <<<"$pref_out" | awk -F: '{print $2}' | trim || true)
fi

# Fallbacks to env if not detectable
: "${protocol_label:=${PROTOCOL:-}}"
: "${cipher_label:=${CIPHER:-}}"
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
# info metric with labels (strings go in labels)
printf 'expressvpn_connection_info{server="%s",protocol="%s",cipher="%s",network_lock="%s"} 1\n' \
  "${server_label//\"/\\\"}" "${protocol_label//\"/\\\"}" "${cipher_label//\"/\\\"}" "${network_lock_label//\"/\\\"}"

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
