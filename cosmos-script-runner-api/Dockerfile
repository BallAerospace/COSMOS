FROM cosmos-base

WORKDIR /src/
COPY Gemfile .
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

COPY . .

EXPOSE 2902
CMD ["rails", "s", "-b", "0.0.0.0", "-p", "2902"]
