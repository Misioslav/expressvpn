FROM ubuntu:bionic

ENV CODE code
ENV SERVER smart
ARG VERSION=expressvpn_2.4.4.19-1_amd64.deb

COPY ./files/${VERSION} /expressvpn/${VERSION}

RUN apt-get update && apt-get install -y \
    expect curl ca-certificates iproute2 cron \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y

COPY ./files/start.sh /expressvpn/start.sh
COPY ./files/activate.sh /expressvpn/activate.sh
COPY ./files/status.sh status.sh
COPY ./files/cron /etc/cron.d/cron

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
