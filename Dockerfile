FROM debian:buster-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ARG VERSION="expressvpn_3.0.2.12-1_amd64.deb"

COPY files/ /expressvpn/

RUN apt-get update && apt-get install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq \
    && wget -q https://download.expressvpn.xyz/clients/linux/${VERSION} -O /expressvpn/${VERSION} \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge --autoremove -y wget \
	&& rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
