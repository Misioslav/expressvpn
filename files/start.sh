#!/usr/bin/bash
cp /etc/resolv.conf /etc/resolv.conf.bak
umount /etc/resolv.conf
cp /etc/resolv.conf.bak /etc/resolv.conf
rm /etc/resolv.conf.bak
sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn
service expressvpn restart
expect /expressvpn/activate.sh
expressvpn preferences set preferred_protocol lightway_udp
expressvpn preferences set lightway_cipher chacha20
bash /expressvpn/uname.sh
expressvpn preferences set auto_connect true
expressvpn connect $SERVER
for i in $(echo $WHITELIST_DNS | sed "s/ //g" | sed "s/,/ /g")
do
    iptables -A xvpn_dns_ip_exceptions -d 1.1.1.1/32 -p udp -m udp --dport 53 -j ACCEPT
    echo "allowing dns server traffic in iptables: $i"
done

touch /var/log/temp.log
tail -f /var/log/temp.log

exec "$@"
