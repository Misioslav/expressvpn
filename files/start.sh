#!/usr/bin/bash
cp /etc/resolv.conf /etc/resolv.conf.bak
umount /etc/resolv.conf
cp /etc/resolv.conf.bak /etc/resolv.conf
rm /etc/resolv.conf.bak
service expressvpn restart
expect /expressvpn/logout.sh
expect /expressvpn/activate.sh
expressvpn connect $SERVER
expressvpn protocol udp

chmod 0644 /etc/cron.d/cron
crontab /etc/cron.d/cron
touch /var/log/cron.log
cron && tail -f /var/log/cron.log

exec "$@"
