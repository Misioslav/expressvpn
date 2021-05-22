#!/usr/bin/bash
cp /etc/resolv.conf /etc/resolv.conf.bak
umount /etc/resolv.conf
cp /etc/resolv.conf.bak /etc/resolv.conf
rm /etc/resolv.conf.bak
sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn
service expressvpn restart
expect /expressvpn/activate.sh
expressvpn connect $SERVER
expressvpn protocol lightway_udp
expressvpn preferences set lightway_cipher chacha20
expressvpn autoconnect true

touch /var/log/temp.log
tail -f /var/log/temp.log

exec "$@"
