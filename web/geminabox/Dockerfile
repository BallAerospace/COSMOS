FROM cosmos_base

COPY . /app
WORKDIR /app
RUN bundle install

EXPOSE 9292

CMD bundle exec rackup --host 0.0.0.0
