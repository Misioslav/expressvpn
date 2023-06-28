#!/usr/bin/bash

kv=$(uname -r | awk -F '.' '{
        if ($1 < 4) { print 1; }
        else if ($1 == 4) {
            if ($2 <= 9) { print 1; }
            else { print 0; }
        }
        else { print 0; }
    }')

if [[ $NETWORK = "on" ]];
then
	if [[ $kv = 0 ]];
	then
		expressvpn preferences set network_lock $NETWORK
	else
		echo "Kernel Version is lower than minimum version of required kernel (4.9), network_lock will be disabled."
		expressvpn preferences set network_lock off
	fi
else
	expressvpn preferences set network_lock $NETWORK
fi