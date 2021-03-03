FROM cosmos-base

WORKDIR /src/

# Copy the local package files to the container's workspace
COPY . .

# Download and setup COSMOS devel area
RUN bundle config set --local without 'development' && \
  bundle install --quiet

EXPOSE 2901

CMD ["rails", "s", "-b", "0.0.0.0", "-p", "2901"]
