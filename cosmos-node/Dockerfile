FROM ballaerospace/cosmosc2-ruby

USER root

RUN apk update \
  && apk add yarn \
  && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

USER ${USER_ID}:${GROUP_ID}