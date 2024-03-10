ARG DISTRIBUTION

FROM debian:${DISTRIBUTION}-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ENV NETWORK="on"
ENV PROTOCOL="lightway_udp"
ENV CIPHER="chacha20"

ARG NUM
ARG PLATFORM
ARG TARGETPLATFORM

COPY files/ /expressvpn/

RUN apt update && apt install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq iptables iputils-ping

RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
    dpkg --add-architecture armhf \
    && apt update && apt install -y --no-install-recommends \
    libc6:armhf libstdc++6:armhf \
    && cd /lib && ln -s arm-linux-gnueabihf/ld-2.23.so ld-linux.so.3; \
    fi

RUN wget -q https://www.expressvpn.works/clients/linux/expressvpn_${NUM}-1_${PLATFORM}.deb -O /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && dpkg -i /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && rm -rf /expressvpn/*.deb

RUN apt-get purge --autoremove -y wget \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
