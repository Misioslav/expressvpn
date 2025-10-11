# ExpressVPN

Container-based on [polkaned/expressvpn](https://github.com/polkaned/dockerfiles/tree/master/expressvpn) version. This is my attempt mostly to learn more about docker.

## Project Structure

- `files/` - Core container scripts, configuration files, and sample config
- `control server/` - HTTP control server testing and demonstration tools
- `Dockerfile` - Container build configuration
- `expressbuild.sh` - Build script for multiple platforms and distributions

## FEATURES

- **Latest Libraries**: All system packages are upgraded to their newest versions during build for enhanced security and compatibility
- **Multi-Distribution Support**: Supports both `debian trixie-slim` (default) and `debian bullseye-slim` distributions
- **Automatic Package Updates**: Built-in `apt-get upgrade` ensures the latest security patches and bug fixes

## TAGS

Latest tag is based on `debian trixie-slim`.
It is possible to use `debian bullseye-slim` base with `-bullseye` tags.
Numbers in the tag corresponds to ExpressVPN version.

## PROTOCOL AND CIPHER

You can change it by env variables `protocol` and `cipher`.

Available protocols:
- `lightway_tcp`
- `lightway_udp` - default value
- `tcp`
- `udp`
- `auto`

Cipher available **only** with lightway:
- `aes`
- `chacha20` - default value
- `auto`

## NETWORK_LOCK

Currently, `network_lock` is turned on by default but in case of any issues you can turn it off by setting env variable `NETWORK` to `off`.
In most cases when `network_lock` cannot be used it is caused by old kernel version. Apparently, the minimum kernel version where `network_lock` is supported is **4.9**.

*A script is included that checks if the host's kernel version meets minimum requirements to allow `network_lock`. If not and the user sets or leaves the default setting `network_lock` to `on`, then `network_lock` will be disabled to allow expressvpn to run.*

## AUTO_UPDATE

It is now possible to set env variable AUTO_UPDATE with value "on" for the container. It will cause the container to try to update upon container restart. If not set or set to a different value than "on" container will not try to update expressvpn automatically.

**Available from 3.61.0.12 tag.**

## WHITELIST_DNS

New env is available. It can be used like in the examples below and it is a comma seperated list of dns servers you wish to use and whitelist via iptables. Don't use it or leave empty for default behavior.
Added by [phynias](https://github.com/phynias), thank you!

## HEALTHCHECK
Healthcheck is performed once every 2min.
You can also add `--env=DDNS=domain` or `--env=IP=yourIP` to docker run command or in the environment section of compose in order to perform healthcheck which will be checking if data from env variable DDNS or IP is different than ExpressVPN's IP.
If you won't set any of them, by default healthcheck will return status `healthy`.
Also, there is a possibility to add `--env=BEAERER=access_token` from [ipinfo.io](https://ipinfo.io/) if you have an account there (free plan gives you 50k requests per month).

Additionally, healthchecks.io support has been added and you can add the id of the healthchecks link to the `HEALTHCHECK` variable in docker configs.
DDNS or IP must be set for ipinfo.io and healthcheck.io to work. 

## DNS LEAKING CHECK
In order to avoid DNS leaking, you have to replace `resolv.conf` on other containers that uses this one to connect to the network with the `resolv.conf` from expressvpn after it connects.

In order to test if DNS is leaking you can use the following script from [macvk/dnsleaktest](https://github.com/macvk/dnsleaktest) repo and run it inside the container for example:

`curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/refs/heads/master/dnsleaktest.sh | docker exec -i expressvpn bash -s`

If you do not know how to replace the `resolv.conf` file. [polkaned/expressvpn](https://github.com/polkaned/dockerfiles/tree/master/expressvpn) provides a simple way to do it.
Just a note, `resolv.conf` might need to be copied over to other containers each time expressvpn reconnects.

## SOCKS5
Environment variables for SOCKS5

| ENV|Desciption|Value|
| :--- |:---| :---:|
| SOCKS|Enable/disable socks5|off|
| SOCKS_IP|Socks IP|0.0.0.0|
| SOCKS_PORT|Socks port|1080|
| SOCKS_USER|Socks username|None|
| SOCKS_PASS|Socks password|None|
| SOCKS_WHITELIST|**(User&Pass required)** Comma-separated whitelist of ip addresses, that may use the proxy without user/pass authentication|None|
| SOCKS_AUTH_ONCE|**(User&Pass required)** Once a specific ip address is authed successfully with user/pass, it is added to a whitelist and may use the proxy without auth|false|
| SOCKS_LOGS|Enable/disable logging|on|

## CONTROL SERVER
HTTP API for controlling ExpressVPN container remotely

| ENV|Description|Value|
| :--- |:---| :---:|
| CONTROL_SERVER|Enable/disable HTTP control server|off|
| CONTROL_IP|Control server IP|0.0.0.0|
| CONTROL_PORT|Control server port|8000|

### Authentication
The control server supports authentication via a configuration file. Create a `config.toml` file and mount it to `/expressvpn/auth/config.toml`. A sample configuration file is available in the `files/` directory.

#### Supported Authentication Types

**1. Basic Authentication (HTTP Basic Auth)**
- Uses username and password
- Credentials are sent in the `Authorization: Basic` header
- Base64 encoded username:password

```toml
[[roles]]
name = "admin"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "basic"
username = "admin"
password = "changeme"
```

**2. API Key Authentication (Bearer Token)**
- Uses a single API key for authentication
- Key is sent in the `Authorization: Bearer` header
- Suitable for programmatic access and integrations

```toml
[[roles]]
name = "api_user"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "api_key"
api_key = "your-secret-api-key-here"
```

**3. No Authentication (Explicitly Disabled)**
- Explicitly disable authentication with `auth = "none"`
- All endpoints are accessible without credentials
- **Warning**: Only use this in trusted environments

```toml
[[roles]]
name = "open_access"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "none"
```

**4. No Authentication (Legacy - No Config File)**
- If no `config.toml` file is mounted, authentication is disabled
- All endpoints are accessible without credentials
- **Warning**: Only use this in trusted environments

#### Role-Based Access Control
- Multiple roles can be defined with different permissions
- Each role can have access to specific routes
- Routes are defined as HTTP method and path combinations

```toml
# Admin role with full access
[[roles]]
name = "admin"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "POST /v1/connect", "POST /v1/disconnect", "GET /v1/health"]
auth = "basic"
username = "admin"
password = "changeme"

# Read-only role for monitoring
[[roles]]
name = "readonly"
routes = ["GET /v1/status", "GET /v1/servers", "GET /v1/dns", "GET /v1/ip", "GET /v1/dnsleak", "GET /v1/health"]
auth = "basic"
username = "readonly"
password = "readonly123"
```

#### Security Considerations

**Authentication Best Practices:**
- Use strong, unique passwords for each role
- Regularly rotate credentials
- Use read-only roles for monitoring applications
- Only grant admin access to trusted users
- Consider using environment variables for sensitive credentials

**Network Security:**
- The control server binds to `0.0.0.0` by default (all interfaces)
- Consider binding to specific interfaces in production: `CONTROL_IP=127.0.0.1`
- Use firewall rules to restrict access to the control port
- Consider using a reverse proxy with SSL/TLS termination

**Configuration Security:**
- Store `config.toml` files securely with appropriate permissions
- Avoid committing credentials to version control
- Use Docker secrets or environment variables for sensitive data

### API Endpoints
- `GET /v1/status` - Get ExpressVPN connection status
- `GET /v1/servers` - List available servers
- `GET /v1/dns` - Get DNS configuration information
- `GET /v1/ip` - Get public IP information and location
- `GET /v1/dnsleak` - Run DNS leak test using macvk/dnsleaktest
- `POST /v1/connect` - Connect to a specific server (requires JSON body: `{"server": "server_name"}`)
- `POST /v1/disconnect` - Disconnect from VPN
- `GET /v1/health` - Health check endpoint

### Example Usage

**Basic Authentication:**
```bash
# Check status
curl -u admin:changeme http://localhost:8000/v1/status

# List servers
curl -u admin:changeme http://localhost:8000/v1/servers

# Get DNS information
curl -u admin:changeme http://localhost:8000/v1/dns

# Get public IP and location
curl -u admin:changeme http://localhost:8000/v1/ip

# Run DNS leak test
curl -u admin:changeme http://localhost:8000/v1/dnsleak

# Connect to a server
curl -u admin:changeme -X POST -H "Content-Type: application/json" \
  -d '{"server": "smart"}' http://localhost:8000/v1/connect

# Disconnect
curl -u admin:changeme -X POST http://localhost:8000/v1/disconnect
```

**API Key Authentication:**
```bash
# Check status
curl -H "Authorization: Bearer your-secret-api-key-here" http://localhost:8000/v1/status

# List servers
curl -H "Authorization: Bearer your-secret-api-key-here" http://localhost:8000/v1/servers

# Get DNS information
curl -H "Authorization: Bearer your-secret-api-key-here" http://localhost:8000/v1/dns

# Get public IP and location
curl -H "Authorization: Bearer your-secret-api-key-here" http://localhost:8000/v1/ip

# Run DNS leak test
curl -H "Authorization: Bearer your-secret-api-key-here" http://localhost:8000/v1/dnsleak

# Connect to a server
curl -H "Authorization: Bearer your-secret-api-key-here" -X POST -H "Content-Type: application/json" \
  -d '{"server": "smart"}' http://localhost:8000/v1/connect

# Disconnect
curl -H "Authorization: Bearer your-secret-api-key-here" -X POST http://localhost:8000/v1/disconnect
```

**No Authentication (when auth = "none" or no config file):**
```bash
# All endpoints accessible without credentials
curl http://localhost:8000/v1/status
curl http://localhost:8000/v1/servers
curl http://localhost:8000/v1/dns
curl http://localhost:8000/v1/ip
curl http://localhost:8000/v1/dnsleak
```

### Testing and Demo Tools

The project contains testing and demonstration tools:

- **`files/config.toml.example`** - Sample configuration file for authentication
- **`control server/test-control-server.sh`** - Comprehensive test script for all API endpoints
- **`control server/demo-new-endpoints.sh`** - Demonstration script for DNS, IP, and DNS leak test endpoints

To test the control server:

```bash
# Run comprehensive tests with basic authentication (default)
./control\ server/test-control-server.sh

# Run tests with API key authentication
AUTH_TYPE=api_key API_KEY=your-secret-api-key ./control\ server/test-control-server.sh

# Run tests with no authentication
AUTH_TYPE=none ./control\ server/test-control-server.sh

# Demo new endpoints with basic authentication
./control\ server/demo-new-endpoints.sh

# Demo with API key authentication
AUTH_TYPE=api_key API_KEY=your-secret-api-key ./control\ server/demo-new-endpoints.sh
```

### Response Examples

**DNS Information (`GET /v1/dns`):**
```json
{
  "dns_servers": ["10.0.0.1", "8.8.8.8"],
  "resolv_conf": "nameserver 10.0.0.1\nnameserver 8.8.8.8\n"
}
```

**Public IP Information (`GET /v1/ip`):**
```json
{
  "ip": "203.0.113.1",
  "country": "US",
  "city": "New York",
  "organization": "ExpressVPN",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**DNS Leak Test (`GET /v1/dnsleak`):**
```json
{
  "dns_servers_found": ["203.0.113.1", "203.0.113.2"],
  "test_summary": "No DNS leaks detected",
  "raw_output": "Testing for DNS leaks...\nFound 2 DNS servers\nNo leaks detected",
  "timestamp": "2024-01-15T10:30:00Z"
}
```



## BUILDING

To build the container locally with the latest changes:

```bash
# Build with default trixie-slim distribution
./expressbuild.sh 3.61.0.12 test-repo

# Build with bullseye-slim distribution
./expressbuild.sh 3.61.0.12 test-repo bullseye-slim

# Build matrix (both distributions)
./expressbuild.sh 3.61.0.12 test-repo matrix
```

## Download

`docker pull misioslav/expressvpn`

## Start the container

```
    docker run \
    --env=CODE=code \
    --env=SERVER=smart \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --privileged \
    --detach=true \
    --tty=true \
    --name=expressvpn \
    --publish 80:80 \ #optional
    --publish 1080:1080 \ #optional for socks5
    --publish 8000:8000 \ #optional for control server
    --env=DDNS=domain \ #optional
    --env=IP=yourIp \ #optional
    --env=BEARER=ipInfoAccessToken \ #optional
    --env=NETWORK=on/off \ #optional set to on by default
    --env=PROTOCOL=lightway_udp \ #optional set default to lightway_udp see protocol and cipher section for more information
    --env=CIPHER=chacha20 \ #optional set default to chacha20 see protocol and cipher section for more information
    --env=WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8 \ #optional
    --env=SOCKS=off \ #optional
    --env=SOCKS_IP=0.0.0.0 \ #optional
    --env=SOCKS_PORT=1080 \ #optional
    --env=SOCKS_USER=someuser \ #optional (required if providing password)
    --env=SOCKS_PASS=somepass \ #optional (required if providing username)
    --env=SOCKS_WHITELIST=192.168.1.1 \ #optional
    --env=SOCKS_AUTH_ONCE=false \ #optional
    --env=SOCKS_LOGS=true \ #optional
    --env=CONTROL_SERVER=off \ #optional
    --env=CONTROL_IP=0.0.0.0 \ #optional
    --env=CONTROL_PORT=8000 \ #optional
    --volume ./files/config.toml:/expressvpn/auth/config.toml \ #optional for control server auth
    misioslav/expressvpn \
    /bin/bash
```


Another container that will use ExpressVPN network:

```
    docker run \
    --name=example \
    --net=container:expressvpn \
    maintainer/example:version
```

## Docker Compose

```
services:

  example:
    image: maintainer/example:version
    container_name: example
    network_mode: service:expressvpn
    depends_on:
      expressvpn:
        condition: service_healthy # This forces the dependent container to wait for the expressvpn container to report healthy. It helps prevent traffic before expressvpn is connected.

  expressvpn:
    image: misioslav/expressvpn:latest
    container_name: expressvpn
    restart: unless-stopped
    ports: # ports from which container that uses expressvpn connection will be available in local network
      - 80:80 # example & optional
      - 1080:1080 # example & optional, commonly used socks5 port
      - 8000:8000 # example & optional, control server port
    environment:
      # - WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8  # optional - Comma seperated list of dns servers you wish to use and whitelist via iptables. DO NOT set this unless you know what you are doing. Whitelisting could cause traffic to circumvent the VPN and cause a DNS leak.
      - CODE=code # Activation Code from ExpressVPN https://www.expressvpn.com/support/troubleshooting/find-activation-code/
      - SERVER=smart # By default container will connect to smart location, list of available locations you can find below
      - DDNS=yourDdnsDomain # optional
      - IP=yourStaticIp # optional - won't work if DDNS is setup
      #### These will only work if DDNS or IP are set. ####
      - BEAERER=ipInfoAccessToken # optional can be taken from ipinfo.io
      - HEALTHCHECK=healthchecks.ioId # optional can be taken from healthchecks.io
      #####################################################
      - NETWORK=off/on #optional and set to on by default (This is the killswitch)
      - PROTOCOL=lightway_udp #optional set default to lightway_udp see protocol and cipher section for more information
      - CIPHER=chacha20 #optional set default to chacha20 see protocol and cipher section for more information
      - SOCKS=off #optional set default to off see socks5 section for more information
      - SOCKS_IP=0.0.0.0 #optional set default to 0.0.0.0 
      - SOCKS_PORT=1080 #optional set default to 1080 
      - SOCKS_USER=someuser #optional set default to NONE 
      - SOCKS_PASS=somepass #optional set default to NONE 
      - SOCKS_WHITELIST=192.168.1.1 #optional set default to NONE 
      - SOCKS_AUTH_ONCE=false #optional set default to false 
      - SOCKS_LOGS=true #optional set default to true 
      - CONTROL_SERVER=off #optional set default to off see control server section for more information
      - CONTROL_IP=0.0.0.0 #optional set default to 0.0.0.0
      - CONTROL_PORT=8000 #optional set default to 8000
    volumes:
      - ./files/config.toml:/expressvpn/auth/config.toml # optional for control server auth
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