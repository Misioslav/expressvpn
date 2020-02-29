#!/usr/bin/sh
service expressvpn restart
/usr/bin/expect /expressvpn/activate.sh
expressvpn connect $env(SERVER)
exec "$@"