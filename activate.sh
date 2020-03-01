#!/usr/bin/expect
spawn expressvpn activate
expect "Enter activation code:"
send "$env(CODE)\r"
expect "These reports never contain personally identifiable information."
send "n\r"
expect eof
