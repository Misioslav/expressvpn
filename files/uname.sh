#!/bin/bash
set -euo pipefail

kernel_version="$(uname -r)"
IFS=.- read -r major minor _ <<<"$kernel_version"
major=${major:-0}
minor=${minor:-0}

required_major=4
required_minor=9

network_mode="${NETWORK:-on}"

set_network_lock() {
    local value="$1"
    case "$value" in
        on) value="true" ;;
        off) value="false" ;;
    esac
    expressvpnctl set networklock "$value"
}

supports_network_lock() {
    if (( major > required_major )); then
        return 0
    fi

    if (( major == required_major && minor >= required_minor )); then
        return 0
    fi

    return 1
}

if [[ "$network_mode" != "on" ]]; then
    set_network_lock "$network_mode"
    exit 0
fi

if supports_network_lock; then
    set_network_lock on
else
    echo "Kernel version ${kernel_version} is lower than the minimum required (4.9); network_lock will be disabled."
    set_network_lock off
fi
