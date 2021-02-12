FROM cosmos-base

WORKDIR /src/

# Copy the local package files to the container's workspace
COPY . /src/

# Download and setup COSMOS devel area
RUN ["gem", "install", "bundler", "--no-document"]

RUN ["bundle", "install", "--quiet"]

EXPOSE 7777

CMD ["rails", "s", "-b", "0.0.0.0", "-p", "7777"]