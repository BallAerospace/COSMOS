ARG COSMOS_REGISTRY=docker.io
ARG COSMOS_TAG=latest

FROM ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-ruby:${COSMOS_TAG}

WORKDIR /cosmos/

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} . .

USER root

RUN mkdir -p lib/cosmos/ext \
  && git config --global http.sslCAinfo /devel/cacert.pem \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && rake gems \
  && gem install --local ./cosmosc2-*.gem \
  && mkdir -p gems \
  && mv *.gem gems/. \
  && gem cleanup \
  && rm -rf /usr/lib/ruby/gems/*/cache/* /var/cache/apk/* /tmp/* /var/tmp/*

RUN mkdir /gems && chown cosmos:cosmos /gems

USER ${USER_ID}:${GROUP_ID}
