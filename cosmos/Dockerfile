FROM ballaerospace/cosmosc2-ruby

ENV RUBYLIB=/cosmos/lib
ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos/

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} . .

USER root

RUN mkdir -p lib/cosmos/ext \
  && git config --global http.sslCAinfo /devel/cacert.pem \
  && apk add build-base ruby-dev libressl-dev \
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
