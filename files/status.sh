#!/bin/sh

echo
echo "ExpressVPN connection status and server its conncted to"
echo

expressvpn status

echo
echo "Your current IP from the server you are connected to"
echo

curl ipinfo.io
