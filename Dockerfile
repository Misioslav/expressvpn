ARG DISTRIBUTION="bullseye-slim"

FROM debian:${DISTRIBUTION}-slim AS microsocks-builder

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential git ca-certificates; \
    git clone https://github.com/rofl0r/microsocks.git /tmp/microsocks; \
    make -C /tmp/microsocks; \
    strip /tmp/microsocks/microsocks; \
    apt-get purge -y --auto-remove build-essential git; \
    rm -rf /var/lib/apt/lists/*

FROM debian:${DISTRIBUTION}-slim

ENV CODE="code" \
    SERVER="smart" \
    HEALTHCHECK="" \
    BEARER="" \
    NETWORK="on" \
    PROTOCOL="lightway_udp" \
    CIPHER="chacha20" \
    SOCKS="off" \
    SOCKS_LOGS="true" \
    SOCKS_AUTH_ONCE="false" \
    SOCKS_USER="" \
    SOCKS_PASS="" \
    SOCKS_IP="0.0.0.0" \
    SOCKS_PORT="1080" \
    SOCKS_WHITELIST=""

ARG NUM
ARG PLATFORM
ARG TARGETPLATFORM

COPY files/ /expressvpn/
COPY --from=microsocks-builder /tmp/microsocks/microsocks /usr/local/bin/microsocks

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        expect \
        curl \
        ca-certificates \
        iproute2 \
        jq \
        iptables \
        iputils-ping \
        net-tools; \
    if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        dpkg --add-architecture armhf; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            libc6:armhf \
            libstdc++6:armhf \
            patchelf; \
        ln -sf /usr/lib/arm-linux-gnueabihf/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3; \
        ln -sf /usr/lib/arm-linux-gnueabihf /lib/arm-linux-gnueabihf; \
    fi

RUN set -eux; \
    curl -fsSL "https://www.expressvpn.works/clients/linux/expressvpn_${NUM}-1_${PLATFORM}.deb" -o /tmp/expressvpn.deb; \
    dpkg -i /tmp/expressvpn.deb; \
    rm -f /tmp/expressvpn.deb

RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        patchelf --set-interpreter /lib/ld-linux-armhf.so.3 /usr/bin/expressvpn; \
        patchelf --set-interpreter /lib/ld-linux-armhf.so.3 /usr/bin/expressvpn-browser-helper; \
    fi

RUN set -eux; \
    if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        apt-get purge -y --auto-remove patchelf; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
