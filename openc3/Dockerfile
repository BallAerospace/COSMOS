ARG OPENC3_REGISTRY=docker.io
ARG OPENC3_TAG=latest

FROM ${OPENC3_REGISTRY}/openc3/openc3-ruby:${OPENC3_TAG}

WORKDIR /openc3/

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} . .

USER root

RUN mkdir -p lib/openc3/ext \
  && git config --global http.sslCAinfo /devel/cacert.pem \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && rake gems \
  && gem install --local ./openc3-*.gem \
  && mkdir -p gems \
  && mv *.gem gems/. \
  && gem cleanup \
  && rm -rf /usr/lib/ruby/gems/*/cache/* /var/cache/apk/* /tmp/* /var/tmp/*

RUN mkdir /gems && chown openc3:openc3 /gems

USER ${USER_ID}:${GROUP_ID}
