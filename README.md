# ExpressVPN

Containerised ExpressVPN client inspired by [polkaned/expressvpn](https://github.com/polkaned/dockerfiles/tree/master/expressvpn), extended with control and observability tooling for multi-platform deployments.

## Table of Contents
- [Project Structure](#project-structure)
- [Features](#features)
- [Supported Tags](#supported-tags)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Protocol and Cipher](#protocol-and-cipher)
  - [Network Lock](#network-lock)
  - [Auto Update](#auto-update)
  - [DNS Whitelist](#dns-whitelist)
  - [Prometheus Metrics (Optional)](#prometheus-metrics-optional)
  - [Healthcheck](#healthcheck)
  - [DNS Leak Check](#dns-leak-check)
  - [SOCKS5 Proxy](#socks5-proxy)
  - [Control Server](#control-server)
- [Control Server API](#control-server-api)
  - [Authentication](#authentication)
  - [API Endpoints](#api-endpoints)
  - [Example Usage](#example-usage)
- [Building](#building)
- [Docker Compose Example](#docker-compose-example)
- [Available Servers](#available-servers)

## Project Structure
- `Dockerfile` – multi-architecture image build definition.
- `expressbuild.sh` – helper script for building and publishing multi-platform images.
- `files/` – container entrypoint scripts, ExpressVPN automation, exporters, and sample configs (e.g. `config.toml.example`).
- `examples/` – Prometheus scrape configuration and Grafana dashboard templates for observability.

## Features
- **Latest libraries** – base image packages upgraded during build for security and compatibility.
- **Multi-distribution support** – Debian `trixie-slim` (default) and `bullseye-slim` images.
- **Automatic package updates** – optional ExpressVPN auto-upgrade on container restart.
- **Prometheus metrics exporter** – opt-in `/metrics.cgi` endpoint for connection state and interface counters.
- **HTTP control server** – optional API for managing ExpressVPN sessions remotely with configurable auth.
- **SOCKS5 proxy support** – integrated microsocks with flexible authentication and allowlist options.

## Supported Tags
Latest tags are built from `debian trixie-slim`. Use `-bullseye` suffixed tags to target the alternative base. Version numbers match the bundled ExpressVPN release.

## Quick Start
```bash
docker run \
  --name expressvpn \
  --env CODE=your-activation-code \
  --env SERVER=smart \
  --env NETWORK=on \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  --privileged \
  misioslav/expressvpn
```

Expose optional services by setting:
- `METRICS_PROMETHEUS=on` + `--publish 9797:9797` for metrics.
- `CONTROL_SERVER=on` + `--publish 8000:8000` for the control API and mount `config.toml` if authentication is required.

## Configuration

### Protocol and Cipher
Configure via `PROTOCOL` (`lightway_udp`, `lightway_tcp`, `udp`, `tcp`, `auto`) and `CIPHER` (`chacha20`, `aes`, `auto` for Lightway only).

### Network Lock
`NETWORK=on` enables the ExpressVPN kill-switch (default). Set `NETWORK=off` if your kernel version (< 4.9) does not support network lock or you need to disable it temporarily.

### Auto Update
Enable ExpressVPN package upgrades on container restart with `AUTO_UPDATE=on`. The default is `off`.

### DNS Whitelist
`WHITELIST_DNS=comma,separated,ips` creates iptables exceptions allowing specified DNS servers outside the VPN tunnel.

### Prometheus Metrics (Optional)
Set `METRICS_PROMETHEUS=on` to serve metrics via BusyBox `httpd` on `METRICS_PORT` (default `9797`) and path `METRICS_PATH` (default `/metrics.cgi`). Metrics include:
- `expressvpn_connection_status`
- `expressvpn_connection_info{server,protocol,cipher,network_lock}`
- `expressvpn_vpn_interface_info{interface}`
- `expressvpn_network_rx/tx_bytes_total`
- `expressvpn_network_rx/tx_packets_total`

Reference configs: `examples/prometheus-scrape-example.yml` and `examples/grafana-expressvpn-dashboard.json`.

### Healthcheck
A built-in healthcheck runs every two minutes. You may provide:
- `DDNS` or `IP` to monitor the public IP.
- `HEALTHCHECK` with a [healthchecks.io](https://healthchecks.io/) UUID.
- `BEARER` for an [ipinfo.io](https://ipinfo.io) token to enrich IP checks (optional; 50k requests/month on free tier).

### DNS Leak Check
Replace `resolv.conf` in dependent containers with the VPN-provided file (`/shared_data/resolv.conf` if you copy it out) to avoid leaks. Test inside the container with:
```bash
curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/refs/heads/master/dnsleaktest.sh | docker exec -i expressvpn bash -s
```

### SOCKS5 Proxy
Control Microsocks with:

| ENV | Description | Default |
| --- | --- | --- |
| `SOCKS` | Enable/disable proxy | `off` |
| `SOCKS_IP` | Bind address | `0.0.0.0` |
| `SOCKS_PORT` | Listen port | `1080` |
| `SOCKS_USER` / `SOCKS_PASS` | Credentials (both required) | empty |
| `SOCKS_WHITELIST` | Comma-separated IPs bypass auth | empty |
| `SOCKS_AUTH_ONCE` | Single-use auth (remember IP) | `false` |
| `SOCKS_LOGS` | Enable logs | `true` |

### Control Server
Activate the HTTP control API with:
- `CONTROL_SERVER=on`
- `CONTROL_IP` (default `0.0.0.0`) and `CONTROL_PORT` (default `8000`)

Authentication configuration is supplied via TOML mounted to `/expressvpn/auth/config.toml`. Sample: `files/config.toml.example`.

## Control Server API

### Authentication
Define roles in the TOML config. Supported modes:

1. **Basic authentication** – `auth = "basic"`, `username`, `password`.
2. **API key** – `auth = "api_key"`, `api_key` header value for `Authorization: Bearer`.
3. **No authentication** – `auth = "none"`; exposes endpoints without protection (use only in trusted environments).

Without a config file, all endpoints are unauthenticated for backward compatibility.

Example role definitions:
```toml
[[roles]]
name = "admin"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "basic"
username = "admin"
password = "changeme"

[[roles]]
name = "api_user"
routes = ["GET /v1/status", "POST /v1/connect", "POST /v1/disconnect"]
auth = "api_key"
api_key = "your-secret-api-key"
```

### API Endpoints
- `GET /v1/status` – ExpressVPN connection status.
- `GET /v1/servers` – Available server list (`expressvpn list all`).
- `GET /v1/dns` – Current DNS settings.
- `GET /v1/ip` – Public IP information.
- `GET /v1/dnsleak` – Execute DNS leak test.
- `POST /v1/connect` – Connect to server (`{"server": "smart"}`).
- `POST /v1/disconnect` – Disconnect from VPN.
- `GET /v1/health` – Health probe for automation.

### Example Usage
**Basic authentication**
```bash
curl -u admin:changeme http://localhost:8000/v1/status
curl -u admin:changeme -X POST -H "Content-Type: application/json" \
  -d '{"server": "smart"}' http://localhost:8000/v1/connect
curl -u admin:changeme -X POST http://localhost:8000/v1/disconnect
```

**API key authentication**
```bash
curl -H "Authorization: Bearer your-secret-api-key" http://localhost:8000/v1/status
```

## Building
Use the helper script to build for different distributions and architectures:
```bash
./expressbuild.sh 3.83.0.2 my-repo            # Build trixie image (default) and load locally
./expressbuild.sh 3.83.0.2 my-repo bullseye   # Build bullseye variant
./expressbuild.sh 3.83.0.2 my-repo matrix push
```
The script wraps `docker buildx build` and prunes build cache when running with `load` action.

## Docker Compose Example
```yaml
services:
  example:
    image: maintainer/example
    network_mode: service:expressvpn
    depends_on:
      expressvpn:
        condition: service_healthy

  expressvpn:
    image: misioslav/expressvpn:latest
    container_name: expressvpn
    restart: unless-stopped
    ports:
      - 80:80        # optional service published through VPN
      - 1080:1080    # optional socks5 port
      - 8000:8000    # optional control server
      - 9797:9797    # optional Prometheus metrics
    environment:
      - CODE=code
      - SERVER=smart
      - NETWORK=on
      - AUTO_UPDATE=off
      - METRICS_PROMETHEUS=on
      - CONTROL_SERVER=on
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    command: /bin/bash
    privileged: true
```

## Available Servers
Set `SERVER` to a shortcut (`smart`, `usny`, `uklo`, etc.), a country name, or a full location. View the list from inside the container with:
```bash
expressvpn list all
```
