FROM debian:bullseye-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ARG VERSION="expressvpn_3.6.0.70-1_amd64.deb"

COPY files/ /expressvpn/

RUN apt update && apt install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq \
    && wget -q https://www.expressvpn.works/clients/linux/${VERSION} -O /expressvpn/${VERSION} \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt purge --autoremove -y wget \
    && rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
