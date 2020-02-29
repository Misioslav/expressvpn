FROM ubuntu:bionic

ENV CODE code
ENV SERVER smart
ARG VERSION=expressvpn_2.4.4.19-1_amd64.deb

COPY ./${VERSION} /expressvpn/${VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    expect curl \
    && dpkg -i /expressvpn/${VERSION} \
    && rm -rf /expressvpn/*.deb \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get autoremove -y

COPY ./entrypoint.sh /expressvpn/entrypoint.sh
COPY ./activate.sh /expressvpn/activate.sh

ENTRYPOINT ["/bin/sh", "/expressvpn/entrypoint.sh"]