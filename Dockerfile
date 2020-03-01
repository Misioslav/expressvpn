FROM ubuntu:bionic

ENV CODE code
ENV SERVER smart
ARG VERSION=expressvpn_2.4.4.19-1_amd64.deb

COPY ./${VERSION} /expressvpn/${VERSION}

RUN apt-get update && apt-get install -y \
    expect curl ca-certificates iproute2 \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y

COPY ./start.sh /expressvpn/start.sh
COPY ./activate.sh /expressvpn/activate.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
