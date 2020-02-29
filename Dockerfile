FROM ubuntu:bionic AS build

ENV CODE code
ENV SERVER smart
ARG EXPRESS=expressvpn_2.4.4.19-1_amd64.deb

RUN apt-get update && apt-get install -y \
    wget expect \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q "https://download.expressvpn.xyz/clients/linux/${EXPRESS}" -O /express/${EXPRESS} \
    && dpkg -i /express/${EXPRESS} \
    && rm -rf /express/*.deb \
    && apt-get purge -y --auto-remove wget \
	&& apt-get autoremove -y

COPY entrypoint.sh /express/entrypoint.sh
COPY activate.sh /express/activate.sh

FROM scratch

COPY --from=build /express/ /express/

ENTRYPOINT ["/bin/bash", "/express/entrypoint.sh"]