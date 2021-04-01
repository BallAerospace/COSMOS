FROM cosmos-ruby

ENV RUBYLIB=/cosmos/lib
ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos/
COPY . .
RUN mkdir -p lib/cosmos/ext && \
  git config --global http.sslCAinfo /devel/cacert.pem && \
  gem install bundler && \
  bundle config set --local without 'development' && \
  bundle install --quiet && \
  bundle exec rake build
