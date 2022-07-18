ARG OPENC3_REGISTRY=docker.io
ARG OPENC3_TAG=latest

FROM ${OPENC3_REGISTRY}/openc3/openc3-base:${OPENC3_TAG}

WORKDIR /src/
COPY Gemfile ./

USER root

RUN apk add --virtual .build-dependencies \
     build-base \
     ruby-dev \
     libressl-dev \
   && bundle config set --local without 'development'\
   && bundle install --quiet \
   && apk del .build-dependencies \
   && rm -rf /usr/lib/ruby/gems/*/cache/* \
     /var/cache/apk/* \
     /tmp/* \
     /var/tmp/*

RUN ["chown", "-R", "openc3:openc3", "/src/"]

USER ${USER_ID}:${GROUP_ID}

COPY  --chown=${IMAGE_USER}:${IMAGE_GROUP} ./ ./

EXPOSE 2902

CMD [ "rails", "s", "-b", "0.0.0.0", "-p", "2902" ]
