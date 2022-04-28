ARG COSMOS_REGISTRY=docker.io
ARG COSMOS_TAG=latest

FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-base:${COSMOS_TAG}

WORKDIR /src/
COPY Gemfile ./

USER root

RUN apk add --virtual .build-dependencies \
    build-base \
    ruby-dev \
    libressl-dev \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && apk del .build-dependencies \
  && rm -rf /usr/lib/ruby/gems/*/cache/* \
    /var/cache/apk/* \
    /tmp/* \
    /var/tmp/*

RUN ["chown", "-R", "cosmos:cosmos", "/src/"]

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ./ ./

EXPOSE 2901

CMD [ "rails", "s", "-b", "0.0.0.0", "-p", "2901" ]
