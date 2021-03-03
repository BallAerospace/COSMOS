FROM ubuntu:20.04

# We require a local certificate file so set that up.
# You must place a valid cert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem

RUN DEBIAN_FRONTEND="noninteractive" apt-get update -y && apt-get install -y \
  --no-install-recommends \
  --option "Acquire:http::No-Cache=true" \
  --option "Acquire:http::Pipeline-Depth=0" \
  curl \
  build-essential \
  ruby \
  ruby-dev \
  git \
  netbase \
  zlib1g \
  zlib1g-dev

RUN git config --global http.sslCAinfo /devel/cacert.pem
RUN ["gem", "install", "bundler"]

ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos/
COPY . .

RUN ["bundle", "install", "--quiet"]
RUN ["mkdir", "-p", "lib/cosmos/ext"]
RUN ["bundle", "exec", "rake", "build"]
