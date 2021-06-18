FROM cosmos-ruby

ENV RUBYLIB=/cosmos/lib
ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos/
COPY Gemfile cosmos.gemspec Rakefile /cosmos/
COPY bin/ /cosmos/bin/
COPY tasks/ /cosmos/tasks/
COPY ext/ /cosmos/ext/
RUN mkdir -p lib/cosmos/ext \
  && git config --global http.sslCAinfo /devel/cacert.pem \
  && apk add --virtual .build-dependencies build-base ruby-dev libressl-dev \
  && gem install bundler \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && bundle exec rake build \
  && gem cleanup \
  && apk del .build-dependencies \
  && rm -rf /usr/lib/ruby/gems/*/cache/* /var/cache/apk/* /tmp/* /var/tmp/*

COPY . .
