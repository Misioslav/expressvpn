#!/usr/bin/expect
spawn expressvpn logout
expect "Are you sure you want to logout ExpressVPN account (y/N)"
send "y\r"
expect eof
