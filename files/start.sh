#!/bin/bash

if [[ -f "/etc/resolv.conf" ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak
    umount /etc/resolv.conf >/dev/null
    cp /etc/resolv.conf.bak /etc/resolv.conf
    rm /etc/resolv.conf.bak
fi

sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn

output=$(service expressvpn restart 2>&1)
if [[ $output == *"failed!"* ]]; then
    echo "Service expressvpn restart failed!"
    bash /expressvpn/start.sh
    exit 1
fi

output=$(expect /expressvpn/activate.sh 2>&1)
if [[ $output == *"Please activate your account."* ]]; then
    echo "Activation failed!"
    bash /expressvpn/start.sh
    exit 1
fi

expressvpn preferences set preferred_protocol $PROTOCOL
expressvpn preferences set lightway_cipher $CIPHER
expressvpn preferences set send_diagnostics false
expressvpn preferences set block_trackers true
bash /expressvpn/uname.sh
expressvpn preferences set auto_connect true
expressvpn connect $SERVER

for i in $(echo $WHITELIST_DNS | sed "s/ //g" | sed "s/,/ /g")
do
    iptables -A xvpn_dns_ip_exceptions -d ${i}/32 -p udp -m udp --dport 53 -j ACCEPT
    echo "allowing dns server traffic in iptables: ${i}"
done

touch /var/log/temp.log
tail -f /var/log/temp.log

exec "$@"