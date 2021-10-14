FROM debian:bullseye-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ENV NETWORK="off"
ARG NUM
ARG PLATFORM
ARG VERSION="expressvpn_${NUM}-1_${PLATFORM}.deb"

COPY files/ /expressvpn/

RUN apt update && apt install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq iptables \
    && wget -q https://www.expressvpn.works/clients/linux/${VERSION} -O /expressvpn/${VERSION} \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt purge --autoremove -y wget \
    && rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
