FROM debian:bullseye-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ENV NETWORK="on"
ENV PROTOCOL="lightway_udp"
ENV CIPHER="chacha20"

ARG NUM
ARG PLATFORM

COPY files/ /expressvpn/

RUN apt-get update && apt-get install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq iptables \
    && wget -q https://www.expressvpn.works/clients/linux/expressvpn_${NUM}-1_${PLATFORM}.deb -O /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && dpkg -i /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge --autoremove -y wget \
    && rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
