# ExpressVPN

Container-based on [polkaned/expressvpn](https://github.com/polkaned/dockerfiles/tree/master/expressvpn) version. This is my attempt mostly to learn more about docker.

## FEATURES

- **Latest Libraries**: All system packages are upgraded to their newest versions during build for enhanced security and compatibility
- **Single Distribution**: Targets `debian trixie-slim` on `amd64` only
- **Automatic Package Updates**: Built-in `apt-get upgrade` ensures the latest security patches and bug fixes
- **ExpressVPN 5.x CLI**: Uses the headless-friendly `expressvpnctl` workflow and universal `.run` installer

## TAGS

Latest tag is based on `debian trixie-slim` on `amd64`.
Numbers in the tag corresponds to ExpressVPN version.

## PROTOCOL

You can change it by env variable `PROTOCOL`.

Available protocols:
- `auto`
- `lightwayudp` - default value
- `lightwaytcp`
- `openvpnudp`
- `openvpntcp`
- `wireguard`

## NETWORK_LOCK

Currently, `network_lock` is turned on by default but in case of any issues you can turn it off by setting env variable `NETWORK` to `off`.
In most cases when `network_lock` cannot be used it is caused by old kernel version. Apparently, the minimum kernel version where `network_lock` is supported is **4.9**.

*A script is included that checks if the host's kernel version meets minimum requirements to allow `network_lock`. If not and the user sets or leaves the default setting `network_lock` to `on`, then `network_lock` will be disabled to allow expressvpn to run.*

## ALLOW_LAN
By default `ALLOW_LAN=true` to allow access to services over your LAN while Network Lock is on. Set `ALLOW_LAN=false` to block LAN access.
If you need access from your LAN while the VPN is connected, set `LAN_CIDR` to your local subnet so return traffic routes correctly (e.g. `LAN_CIDR=192.168.55.0/24`).

## ACTIVATION (HEADLESS)
This image uses the ExpressVPN 5.x CLI (`expressvpnctl`) under the hood. Activation is handled automatically from the `CODE` environment variable.
The CLI requires background mode for headless use, and this is enabled during startup.

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

## PROMETHEUS METRICS (OPTIONAL)
Enable the metrics exporter with:
- `METRICS_PROMETHEUS=on`
- `METRICS_PORT=9797`
- `METRICS_PATH=/metrics.cgi`

Expose the port (e.g., `-p 9797:9797`) and scrape `/metrics.cgi` or `/metrics`.

## CONTROL SERVER (OPTIONAL)
Enable the HTTP control API with:
- `CONTROL_SERVER=on`
- `CONTROL_IP=0.0.0.0`
- `CONTROL_PORT=8000`

Optional auth config file can be mounted to `/expressvpn/config.toml`. See `files/config.toml.example`.



## BUILDING

To build the container locally with the latest changes:

```bash
# Build with default trixie-slim distribution on amd64
./expressbuild.sh 5.0.1.11498 test-repo
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
    --publish 8000:8000 \ #optional control server
    --publish 9797:9797 \ #optional metrics
    --env=DDNS=domain \ #optional
    --env=IP=yourIp \ #optional
    --env=BEARER=ipInfoAccessToken \ #optional
    --env=NETWORK=on/off \ #optional set to on by default
    --env=ALLOW_LAN=true \ #optional allow LAN access while Network Lock is on
    --env=LAN_CIDR=192.168.55.0/24 \ #optional LAN subnet for return routing
    --env=PROTOCOL=lightwayudp \ #optional set default to lightwayudp see protocol section for more information
    --env=WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8 \ #optional
    --env=METRICS_PROMETHEUS=on \ #optional
    --env=CONTROL_SERVER=on \ #optional
    --env=SOCKS=off \ #optional
    --env=SOCKS_IP=0.0.0.0 \ #optional
    --env=SOCKS_PORT=1080 \ #optional
    --env=SOCKS_USER=someuser \ #optional (required if providing password)
    --env=SOCKS_PASS=somepass \ #optional (required if providing username)
    --env=SOCKS_WHITELIST=192.168.1.1 \ #optional
    --env=SOCKS_AUTH_ONCE=false \ #optional
    --env=SOCKS_LOGS=true \ #optional
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
      - 8000:8000 # optional control server
      - 9797:9797 # optional metrics
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
      - ALLOW_LAN=true #optional allow LAN access while Network Lock is on
      - LAN_CIDR=192.168.55.0/24 #optional LAN subnet for return routing
      - PROTOCOL=lightwayudp #optional set default to lightwayudp see protocol section for more information
      - METRICS_PROMETHEUS=on # optional
      - CONTROL_SERVER=on # optional
      - SOCKS=off #optional set default to off see socks5 section for more information
      - SOCKS_IP=0.0.0.0 #optional set default to 0.0.0.0 
      - SOCKS_PORT=1080 #optional set default to 1080 
      - SOCKS_USER=someuser #optional set default to NONE 
      - SOCKS_PASS=somepass #optional set default to NONE 
      - SOCKS_WHITELIST=192.168.1.1 #optional set default to NONE 
      - SOCKS_AUTH_ONCE=false #optional set default to false 
      - SOCKS_LOGS=true #optional set default to true 
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

You can choose which location ExpressVPN should connect to by setting `SERVER` to a region name or `smart`.

You can check available locations from inside the container by running `expressvpnctl get regions`.
