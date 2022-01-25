FROM ballaerospace/cosmosc2-ruby

ENV RUBYLIB=/cosmos/lib
ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos/

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} Gemfile cosmos.gemspec Rakefile /cosmos/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} bin/ /cosmos/bin/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} tasks/ /cosmos/tasks/
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} ext/ /cosmos/ext/

USER root

RUN mkdir -p lib/cosmos/ext \
  && git config --global http.sslCAinfo /devel/cacert.pem \
  && apk add build-base ruby-dev libressl-dev \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && bundle exec rake build \
  && gem cleanup \
  && rm -rf /usr/lib/ruby/gems/*/cache/* /var/cache/apk/* /tmp/* /var/tmp/*

RUN mkdir /gems && chown cosmos:cosmos /gems

USER ${USER_ID}:${GROUP_ID}

COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} . .
