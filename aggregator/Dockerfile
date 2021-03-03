FROM cosmos-base

WORKDIR /src/
COPY . .
RUN bundle config set --local without 'development' && \
  bundle install --quiet

EXPOSE 2903
CMD ["rails", "s", "-b", "0.0.0.0", "-p", "2903"]
