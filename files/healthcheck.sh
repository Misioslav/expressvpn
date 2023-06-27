#!/bin/bash

if [[ -n $DDNS ]]; then
    checkIP=$(getent hosts "$DDNS" | awk '{ print $1 }')
else
    checkIP=$IP
fi

if [[ -n $checkIP ]]; then
    expressvpnIP=$(curl -s -H "Authorization: Bearer $BEARER" 'ipinfo.io' | jq --raw-output '.ip')
    
    if [[ $checkIP = $expressvpnIP ]]; then
        if [[ -n $HEALTHCHECK ]]; then
            curl -fsS --retry 3 "https://hc-ping.com/$HEALTHCHECK/fail" >/dev/null
        fi
        expressvpn disconnect
        expressvpn connect "$SERVER"
        exit 1
    else
        if [[ -n $HEALTHCHECK ]]; then
            curl -fsS --retry 3 "https://hc-ping.com/$HEALTHCHECK" >/dev/null
        fi
        exit 0
    fi
else
    exit 0
fi
