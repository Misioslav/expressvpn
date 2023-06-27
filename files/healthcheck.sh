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
			curl "https://hc-ping.com/$HEALTHCHECK/fail"
			expressvpn disconnect
			expressvpn connect "$SERVER"
			exit 1
		else
			expressvpn disconnect
			expressvpn connect "$SERVER"
			exit 1
		fi
	else
		if [[ -n $HEALTHCHECK ]]; then
			curl "https://hc-ping.com/$HEALTHCHECK"
			exit 0
		else
			exit 0
		fi
	fi
else
	exit 0
fi