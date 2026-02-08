ARG DISTRIBUTION="trixie-slim"

FROM debian:${DISTRIBUTION} AS microsocks-builder

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends build-essential git ca-certificates; \
    git clone --depth 1 https://github.com/rofl0r/microsocks.git /tmp/microsocks; \
    make -C /tmp/microsocks; \
    strip /tmp/microsocks/microsocks; \
    mv /tmp/microsocks/microsocks /usr/local/bin/microsocks; \
    apt-get purge -y --auto-remove build-essential git; \
    rm -rf /tmp/microsocks; \
    rm -rf /var/lib/apt/lists/*

FROM debian:${DISTRIBUTION}

ENV CODE="code" \
    SERVER="smart" \
    HEALTHCHECK="" \
    BEARER="" \
    NETWORK="on" \
    ALLOW_LAN="true" \
    LAN_CIDR="" \
    PROTOCOL="lightwayudp" \
    METRICS_PROMETHEUS="off" \
    METRICS_PORT="9797" \
    METRICS_PATH="/metrics.cgi" \
    CONTROL_SERVER="off" \
    CONTROL_IP="0.0.0.0" \
    CONTROL_PORT="8000" \
    AUTH_CONFIG="/expressvpn/config.toml" \
    SOCKS="off" \
    SOCKS_LOGS="true" \
    SOCKS_AUTH_ONCE="false" \
    SOCKS_USER="" \
    SOCKS_PASS="" \
    SOCKS_IP="0.0.0.0" \
    SOCKS_PORT="1080" \
    SOCKS_WHITELIST=""

ARG EXPRESSVPN_VERSION="5.1.0.12141"
ARG EXPRESSVPN_RUN_URL="https://www.expressvpn.works/clients/linux/expressvpn-linux-universal-${EXPRESSVPN_VERSION}_release.run"
COPY files/ /expressvpn/
COPY --from=microsocks-builder /usr/local/bin/microsocks /usr/local/bin/microsocks

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        iproute2 \
        jq \
        iptables \
        iputils-ping \
        procps \
        psmisc \
        libatomic1 \
        libglib2.0-0 \
        busybox \
        socat \
        python3 \
        python3-tomli \
        xz-utils; \
    curl -fsSL "${EXPRESSVPN_RUN_URL}" -o /tmp/expressvpn.run; \
    sh /tmp/expressvpn.run --accept --quiet --noprogress -- --no-gui --sysvinit; \
    rm -f /tmp/expressvpn.run; \
    curl -fsSL "https://raw.githubusercontent.com/kavehtehrani/cloudflare-speed-cli/main/install.sh" | sh; \
    mv /root/.local/bin/cloudflare-speed-cli /usr/local/bin/cloudflare-speed-cli; \
    rmdir /root/.local/bin 2>/dev/null || true; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=10s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
