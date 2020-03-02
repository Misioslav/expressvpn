#!/usr/bin/bash
cp /etc/resolv.conf /tmp/resolv.conf
su -c 'umount /etc/resolv.conf'
cp /tmp/resolv.conf /etc/resolv.conf
service expressvpn restart
expect /expressvpn/activate.sh
expressvpn connect $SERVER

chmod 0644 /etc/cron.d/cron
crontab /etc/cron.d/cron
touch /var/log/cron.log
cron && tail -f /var/log/cron.log

exec "$@"
