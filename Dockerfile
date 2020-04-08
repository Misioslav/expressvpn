FROM debian:buster-slim

ENV CODE code
ENV SERVER smart
ARG VERSION=expressvpn_2.4.4.19-1_amd64.deb

COPY ./files/start.sh /expressvpn/start.sh
COPY ./files/activate.sh /expressvpn/activate.sh
COPY ./files/logout.sh /expressvpn/logout.sh
COPY ./files/status.sh status.sh
COPY ./files/cron /etc/cron.d/cron

RUN apt-get update && apt-get install -y --no-install-recommends \
    expect curl ca-certificates iproute2 cron wget \
    && wget -q https://download.expressvpn.xyz/clients/linux/${VERSION} -O /expressvpn/${VERSION} \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge --autoremove -y wget \
	&& rm -rf /var/log/*.log

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
