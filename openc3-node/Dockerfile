ARG OPENC3_REGISTRY=docker.io
ARG OPENC3_TAG=latest

FROM ${OPENC3_REGISTRY}/openc3/openc3-ruby:${OPENC3_TAG}

USER root

RUN apk update \
  && apk add yarn \
  && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

USER ${USER_ID}:${GROUP_ID}