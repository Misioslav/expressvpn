#!/bin/bash

if [[ $AUTO_UPDATE = "on" ]]; then
    DEBIAN_FRONTEND=noninteractive apt update && apt -y -o Dpkg::Options::="--force-confdef" -o \
    Dpkg::Options::="--force-confnew" install -y --only-upgrade expressvpn --no-install-recommends \
    && apt autoclean && apt clean && apt autoremove && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/*.log
fi

if [[ -f "/etc/resolv.conf" ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak
    umount /etc/resolv.conf &>/dev/null
    cp /etc/resolv.conf.bak /etc/resolv.conf
    rm /etc/resolv.conf.bak
fi

sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn

output=$(service expressvpn restart)
if echo "$output" | grep -q "failed!" > /dev/null
then
    echo "Service expressvpn restart failed!"
    exit 1
fi

output=$(expect -f /expressvpn/activate.exp "$CODE")
if echo "$output" | grep -q "Please activate your account" > /dev/null || echo "$output" | grep -q "Activation failed" > /dev/null
then
    echo "Activation failed!"
    exit 1
fi

expressvpn preferences set preferred_protocol $PROTOCOL
expressvpn preferences set lightway_cipher $CIPHER
expressvpn preferences set send_diagnostics false
expressvpn preferences set block_trackers true
bash /expressvpn/uname.sh
expressvpn preferences set auto_connect true
expressvpn connect $SERVER || exit

for i in $(echo $WHITELIST_DNS | sed "s/ //g" | sed "s/,/ /g")
do
    iptables -A xvpn_dns_ip_exceptions -d ${i}/32 -p udp -m udp --dport 53 -j ACCEPT
    echo "allowing dns server traffic in iptables: ${i}"
done

if [[ $SOCKS = "on" ]]; then
    SOCKS_CMD="microsocks "
    
    if [[ $SOCKS_LOGS = "false" ]]; then
        SOCKS_CMD+="-q "
    fi
    
    if [[ -n "$SOCKS_USER" && -z "$SOCKS_PASS" ]] || [[ -z "$SOCKS_USER" && -n "$SOCKS_PASS" ]]; then
        echo "Error: Both SOCKS_USER and SOCKS_PASS must be set, or neither."
        exit
    elif [[ -n "$SOCKS_USER" && -n "$SOCKS_PASS" ]]; then
        
        if [[ $SOCKS_AUTH_ONCE = "true" ]]; then
            SOCKS_CMD+="-1 "
        fi
        
        if [[ $SOCKS_WHITELIST != "" ]]; then
            SOCKS_CMD+="-w $SOCKS_WHITELIST "
        fi
        
        SOCKS_CMD+="-u $SOCKS_USER -P $SOCKS_PASS "
    fi
    SOCKS_CMD+="-i $SOCKS_IP -p $SOCKS_PORT"
    $SOCKS_CMD &
fi

exec "$@"
