#!/usr/bin/expect
set timeout 10
spawn expressvpn activate
expect {
	"Already activated. Logout from your account (y/N)?" {
		send "N\r"
	}
	"Enter activation code:" {
		send "${CODE}\r"
	}
	"Help improve ExpressVPN: Share crash reports, speed tests, usability diagnostics, and whether VPN connection attempts succeed. These reports never contain personally identifiable information. (Y/n)" {
		send "n\r"
	}
}
expect eof