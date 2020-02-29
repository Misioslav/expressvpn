#!/usr/bin/bash
service expressvpn restart
/usr/bin/expect /expressvpn/activate.sh
expressvpn connect $env(SERVER)
exec "$@"
