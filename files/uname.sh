#!/usr/bin/bash

kernel_version=$(uname -r)
major_version="${kernel_version%%.*}"
minor_version="${kernel_version#*.}"
minor_version="${minor_version%%.*}"

if [[ $NETWORK = "on" ]]; then
    if (( major_version < 4 || (major_version == 4 && minor_version <= 9) )); then
        expressvpn preferences set network_lock "$NETWORK"
    else
        echo "Kernel version is lower than the minimum required version (4.9). network_lock will be disabled."
        expressvpn preferences set network_lock off
    fi
else
    expressvpn preferences set network_lock "$NETWORK"
fi
