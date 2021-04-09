FROM cosmos-base

WORKDIR /src/
COPY . .
RUN apk add --virtual .build-dependencies \
           build-base \
           ruby-dev \
           libressl-dev \
&& gem install bundler \
&& bundle config set --local without 'development' \
&& bundle install --quiet \
&& gem cleanup \
&& apk del .build-dependencies \
&& rm -rf /usr/lib/ruby/gems/*/cache/* \
          /var/cache/apk/* \
          /tmp/* \
          /var/tmp/*

EXPOSE 9292
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0"]
