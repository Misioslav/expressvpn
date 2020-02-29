#!/usr/bin/expect
spawn expressvpn activate
expect "Enter activation code:"
send "$env(CODE)\r"
expect "information."
send "n\r"
expect eof