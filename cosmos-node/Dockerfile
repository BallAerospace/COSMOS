ARG COSMOS_REGISTRY=docker.io
ARG COSMOS_TAG=latest

FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-ruby:${COSMOS_TAG}

USER root

RUN apk update \
  && apk add yarn \
  && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

USER ${USER_ID}:${GROUP_ID}