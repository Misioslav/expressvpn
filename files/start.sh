#!/usr/bin/bash
cp /etc/resolv.conf /etc/resolv.conf.bak
umount /etc/resolv.conf
cp /etc/resolv.conf.bak /etc/resolv.conf
rm /etc/resolv.conf.bak
cp expressvpn/expressvpn.service /etc/init.d/expressvpn
service expressvpn restart
expect /expressvpn/activate.sh
expressvpn connect $SERVER
expressvpn protocol udp

touch /var/log/temp.log
tail -f /var/log/temp.log

exec "$@"
