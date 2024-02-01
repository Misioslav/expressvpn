# ExpressVPN

Container-based on [polkaned/expressvpn](https://hub.docker.com/r/polkaned/expressvpn) version. This is my attempt mostly to learn more about docker.

## TAGS

Latest tag is based on `debian bullseye`.
It is possible to use `debian bookworm` base with `-bookworm` tags.
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

## Build

**AMD64**
`docker buildx build --build-arg NUM=<EXPRESSVPN_VERSION> --build-arg DISTRIBUTION=<DEBIAN_DISTRIBUTION> --build-arg PLATFORM=amd64 --platform linux/amd64 -t REPOSITORY/APP:VERSION .`

**ARMv7 (Raspberry Pi)**
`docker buildx build --build-arg NUM=<EXPRESSVPN_VERSION> --build-arg DISTRIBUTION=<DEBIAN_DISTRIBUTION> --build-arg PLATFORM=armhf --platform linux/arm/v7 -t REPOSITORY/APP:VERSION-armhf .`

## Download

`docker pull misioslav/expressvpn`

## Start the container

```
    docker run \
    --env=WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8 \ #optional
    --env=CODE=code \
    --env=SERVER=smart \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --privileged \
    --detach=true \
    --tty=true \
    --name=expressvpn \
    --publish 80:80 \
    --env=DDNS=domain \ #optional
    --env=IP=yourIp \ #optional
    --env=BEARER=ipInfoAccessToken \ #optional
    --env=NETWORK=on/off \ #optional set to on by default
    --env=PROTOCOL=lightway_udp \ #optional set default to lightway_udp see protocol and cipher section for more information
    --env=CIPHER=chacha20 \ #optional set default to chacha20 see protocol and cipher section for more information
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
      - 80:80 # example
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

