# ExpressVPN

Container based on [polkaned/expressvpn](https://github.com/polkaned/dockerfiles/tree/master/expressvpn) with additional features and automation.

## Table of Contents

- [Features](#features)
- [Quickstart (docker run)](#quickstart-docker-run)
- [Docker Compose](#docker-compose)
- [Configuration](#configuration)
- [Protocols](#protocols)
- [Network Lock and LAN Access](#network-lock-and-lan-access)
- [SOCKS5 Proxy](#socks5-proxy)
- [Control Server API](#control-server-api)
- [Prometheus Metrics](#prometheus-metrics)
- [Healthcheck](#healthcheck)
- [DNS Leak Check](#dns-leak-check)
- [Servers Available](#servers-available)
- [Building](#building)
- [Download](#download)

## Features

- ExpressVPN 5.x CLI (`expressvpnctl`) with headless activation.
- Automatic activation via `CODE` and background mode enable.
- Protocol selection with validation.
- Network Lock support with optional LAN access and routed subnets.
- SOCKS5 proxy (microsocks) with auth and whitelist support.
- Prometheus metrics exporter with `/metrics` or custom `.cgi` path.
- Optional control server API to query status and control connections.
- Healthcheck with optional DDNS/IP validation and healthchecks.io support.
- DNS whitelist for custom resolvers.
- Built on `debian:trixie-slim` (amd64) with updated system packages.

## Quickstart (docker run)

```bash
docker run \
  --env=CODE=code \
  --env=SERVER=smart \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --privileged \
  --detach=true \
  --tty=true \
  --name=expressvpn \
  --publish 1080:1080 \
  --publish 8000:8000 \
  --publish 9797:9797 \
  --env=PROTOCOL=lightwayudp \
  --env=ALLOW_LAN=true \
  --env=LAN_CIDR=192.168.55.0/24 \
  --env=METRICS_PROMETHEUS=on \
  --env=CONTROL_SERVER=on \
  --env=SOCKS=off \
  misioslav/expressvpn \
  /bin/bash
```

Another container using the VPN network:

```bash
docker run \
  --name=example \
  --net=container:expressvpn \
  maintainer/example:version
```

## Docker Compose

```yaml
services:
  example:
    image: maintainer/example:version
    container_name: example
    network_mode: service:expressvpn
    depends_on:
      expressvpn:
        condition: service_healthy

  expressvpn:
    image: misioslav/expressvpn:latest
    container_name: expressvpn
    restart: unless-stopped
    ports:
      - 1080:1080 # socks5 (optional)
      - 8000:8000 # control server (optional)
      - 9797:9797 # metrics (optional)
    environment:
      - CODE=code
      - SERVER=smart
      - PROTOCOL=lightwayudp
      - ALLOW_LAN=true
      - LAN_CIDR=192.168.55.0/24
      - METRICS_PROMETHEUS=on
      - CONTROL_SERVER=on
      - SOCKS=off
      # Optional healthcheck/IP validation
      # - DDNS=yourDdnsDomain
      # - IP=yourStaticIp
      # - BEARER=ipInfoAccessToken
      # - HEALTHCHECK=healthchecks.ioId
      # Optional DNS whitelist
      # - WHITELIST_DNS=192.168.1.1,1.1.1.1
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    stdin_open: true
    tty: true
    command: /bin/bash
    privileged: true
```

## SERVERS AVAILABLE

You can choose to which location ExpressVPN should connect to by setting up `SERVER=ALIAS`, `SERVER=COUNTRY`, `SERVER=LOCATION` or `SERVER=SMART`

You can check available locations from inside the container by running `expressvpn list all` command.

## Configuration

Environment variables (defaults shown):

| ENV | Description | Default |
| :--- | :--- | :---: |
| CODE | ExpressVPN activation code | code |
| SERVER | Region name or `smart` | smart |
| PROTOCOL | VPN protocol | lightwayudp |
| NETWORK | Network Lock (`on`/`off`) | on |
| ALLOW_LAN | Allow LAN access while Network Lock is on | true |
| LAN_CIDR | Comma-separated LAN CIDRs for return routes | (empty) |
| WHITELIST_DNS | Comma-separated DNS servers to allow via iptables | (empty) |
| DDNS | Domain to compare with ExpressVPN public IP for healthcheck | (empty) |
| IP | Static IP to compare with ExpressVPN public IP for healthcheck | (empty) |
| BEARER | ipinfo.io bearer token (healthcheck and `/v1/ip`) | (empty) |
| HEALTHCHECK | healthchecks.io UUID | (empty) |
| METRICS_PROMETHEUS | Enable metrics exporter (`on`/`off`) | off |
| METRICS_PORT | Metrics port | 9797 |
| METRICS_PATH | Metrics path (absolute, ends with `.cgi`) | /metrics.cgi |
| CONTROL_SERVER | Enable control server (`on`/`off`) | off |
| CONTROL_IP | Control server bind IP | 0.0.0.0 |
| CONTROL_PORT | Control server port | 8000 |
| AUTH_CONFIG | Auth config file path | /expressvpn/config.toml |
| CLOUDFLARE_SPEED_TIMEOUT | Speed test timeout in seconds (control server) | 120 |
| SOCKS | Enable SOCKS5 proxy (`on`/`off`) | off |
| SOCKS_IP | SOCKS bind IP | 0.0.0.0 |
| SOCKS_PORT | SOCKS port | 1080 |
| SOCKS_USER | SOCKS username | (empty) |
| SOCKS_PASS | SOCKS password | (empty) |
| SOCKS_WHITELIST | Comma-separated IPs bypassing auth | (empty) |
| SOCKS_AUTH_ONCE | Cache auth by IP (`true`/`false`) | false |
| SOCKS_LOGS | Enable microsocks logs (`true`/`false`) | true |

## Protocols

Supported values for `PROTOCOL`:

- auto
- lightwayudp (default)
- lightwaytcp
- openvpnudp
- openvpntcp
- wireguard

## Network Lock and LAN Access

- Network Lock is enabled by default (`NETWORK=on`).
- If your kernel does not support Network Lock (minimum 4.9), it will be disabled at runtime.
- `ALLOW_LAN=true` lets LAN traffic through while Network Lock is on.
- Set `LAN_CIDR` (comma-separated) to add return routes for your LAN subnets.

## SOCKS5 Proxy

Enable the SOCKS5 proxy with:

- `SOCKS=on`
- Optional auth: set both `SOCKS_USER` and `SOCKS_PASS`
- Optional whitelist: `SOCKS_WHITELIST=ip1,ip2`
- Optional cache: `SOCKS_AUTH_ONCE=true`

## Control Server API

Enable the control API with:

- `CONTROL_SERVER=on`
- `CONTROL_IP=0.0.0.0`
- `CONTROL_PORT=8000`

### Endpoints

| Method | Path | Description |
| :--- | :--- | :--- |
| GET | /v1/status | Connection status, server, IP |
| GET | /v1/vpn/status | VPN status (`running`/`stopped`) |
| GET | /v1/vpn/settings | VPN settings (protocol, region, allow_lan) |
| POST | /v1/vpn/settings | Update VPN settings (protocol, region, allow_lan) |
| GET | /v1/servers | List available regions |
| GET | /v1/ip | Public IP info (uses `BEARER` if set) |
| GET | /v1/publicip/ip | Public IP (`{"public_ip":"x.x.x.x"}`) |
| GET | /v1/dns | Resolver info and `/etc/resolv.conf` |
| GET | /v1/dns/status | DNS status (`running`/`stopped`) |
| GET | /v1/dnsleak | DNS leak test result |
| GET | /v1/speedtest | Cloudflare speed test (`cloudflare-speed-cli --json`) |
| GET | /v1/health | API health check |
| POST | /v1/connect | Connect to server (JSON: `{ "server": "smart" }`) |
| POST | /v1/disconnect | Disconnect from VPN |

The speed test endpoint uses `cloudflare-speed-cli` by kavehtehrani:
https://github.com/kavehtehrani/cloudflare-speed-cli

The DNS leak test script is using:
https://github.com/macvk/dnsleaktest

### Authentication

Mount a TOML file at `/expressvpn/config.toml` (or change `AUTH_CONFIG`). Example file: [`example/config.toml.example`](example/config.toml.example).

```toml
[[roles]]
name = "admin"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "GET /v1/speedtest", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "basic"
username = "admin"
password = "changeme"

[[roles]]
name = "api_user"
routes = ["GET /v1/status", "POST /v1/connect", "POST /v1/disconnect"]
auth = "apikey"
apikey = "your-secret-api-key"
```

If the config file is missing, a single role can be defined via environment variables:

- `CONTROL_AUTH_TYPE` (`basic`, `api_key`, or `none`)
- `CONTROL_AUTH_NAME`
- `CONTROL_AUTH_USER`
- `CONTROL_AUTH_PASSWORD`
- `CONTROL_API_KEY`
- `CONTROL_AUTH_ROUTES` (comma-separated `METHOD /path`, default `*`)

Example request:

```bash
curl -u admin:changeme http://localhost:8000/v1/status
```

For API key auth, send the key with:

```bash
curl -H "X-API-Key: your-secret-api-key" http://localhost:8000/v1/status
```

### Example usage

Update VPN settings:

```bash
curl -X POST http://localhost:8000/v1/vpn/settings \
  -H "Content-Type: application/json" \
  -u admin:changeme \
  -d '{"protocol":"lightwayudp","region":"smart","allow_lan":true}'
```

Connect to a region:

```bash
curl -X POST http://localhost:8000/v1/connect \
  -H "Content-Type: application/json" \
  -u admin:changeme \
  -d '{"server":"germany-frankfurt-1"}'
```

Disconnect:

```bash
curl -X POST http://localhost:8000/v1/disconnect \
  -u admin:changeme
```

## Prometheus Metrics

Enable metrics with:

- `METRICS_PROMETHEUS=on`
- `METRICS_PORT=9797`
- `METRICS_PATH=/metrics.cgi` (absolute and must end with `.cgi`)

Metrics are served on `/metrics.cgi` (or `/metrics`) at the configured port.
If the embedded `httpd` cannot bind the port, a socat fallback server is started.

### Exported metrics

- `expressvpn_connection_status` (0/1)
- `expressvpn_connection_state{state}`
- `expressvpn_connection_uptime_seconds`
- `expressvpn_last_state_change_timestamp_seconds`
- `expressvpn_state_changes_total`
- `expressvpn_connect_attempts_total`
- `expressvpn_connect_failures_total`
- `expressvpn_connection_info{server,connected_server,protocol,network_lock}`
- `expressvpn_vpn_ip_info{ip}`
- `expressvpn_public_ip_info{ip}`
- `expressvpn_vpn_interface_info{interface}`
- `expressvpn_vpn_interface_up{interface}`
- `expressvpn_vpn_interface_mtu_bytes{interface}`
- `expressvpn_network_rx_bytes_total{interface}`
- `expressvpn_network_tx_bytes_total{interface}`
- `expressvpn_network_rx_packets_total{interface}`
- `expressvpn_network_tx_packets_total{interface}`
- `expressvpn_network_rx_errors_total{interface}`
- `expressvpn_network_tx_errors_total{interface}`
- `expressvpn_network_rx_dropped_total{interface}`
- `expressvpn_network_tx_dropped_total{interface}`

### Prometheus scrape config example

```yaml
scrape_configs:
  - job_name: expressvpn
    metrics_path: /metrics.cgi
    static_configs:
      - targets: ["expressvpn:9797"]
```

### Grafana dashboard

An example Grafana dashboard is provided at [`example/expressvpn-grafana-dashboard.json`](example/expressvpn-grafana-dashboard.json).
Import it in Grafana and select your Prometheus datasource to view all exported metrics.

## Healthcheck

The container healthcheck runs every 2 minutes.

- Set `DDNS` or `IP` to compare against the ExpressVPN public IP.
- Optional `BEARER` (ipinfo.io token) improves reliability.
- Optional `HEALTHCHECK` posts status to healthchecks.io.

If `DDNS` or `IP` are not set, the healthcheck is always healthy.

## DNS Leak Check

To avoid DNS leaks, update dependent containers to use the `resolv.conf` from this container after connect.

Run the DNS leak test inside the container:

```bash
curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/refs/heads/master/dnsleaktest.sh | docker exec -i expressvpn bash -s
```

## Servers Available

Set `SERVER=smart` or any region name.
On startup with `SERVER=smart`, the container waits briefly for the smart location
to refresh before connecting, so the first connection aligns with the latest smart region.
List regions from inside the container:

```bash
expressvpnctl get regions
```

## Building

```bash
./expressbuild.sh 5.0.1.11498 test-repo
```

## Download

```bash
docker pull misioslav/expressvpn
```
