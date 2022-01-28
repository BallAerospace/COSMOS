# This Dockerfile is for development of COSMOS
# See Docker Hub: ballaerospace/cosmos for production docker images

FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
  cmake \
  default-jdk \
  freeglut3 \
  freeglut3-dev \
  gcc \
  g++ \
  git \
  iproute2 \
  libffi-dev \
  libgdbm-dev \
  libgdbm5 \
  libgstreamer-plugins-base1.0-dev \
  libgstreamer1.0-dev \
  libncurses5-dev \
  libreadline6-dev \
  libsmokeqt4-dev \
  libssl-dev \
  libyaml-dev \
  net-tools \
  postgresql-server-dev-all \
  qt4-default \
  qt4-dev-tools \
  ruby2.5 \
  ruby2.5-dev \
  vim \
  xterm \
  zlib1g-dev

RUN gem install rake --no-document

# We require a local certificate file so set that up.
# You must place a valid cert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cert.pem /devel/cert.pem
ENV SSL_CERT_FILE /devel/cert.pem
ENV CURL_CA_BUNDLE /devel/cert.pem
ENV REQUESTS_CA_BUNDLE /devel/cert.pem
RUN git config --global http.sslCAinfo /devel/cert.pem

# Download and install jruby
RUN cd /opt \
  && curl -G https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.2.9.0/jruby-dist-9.2.9.0-bin.tar.gz > jruby.tar.gz \
  && tar xvf jruby.tar.gz \
  && mv jruby-9.2.9.0 jruby

ARG COSMOS_REPO=https://github.com/BallAerospace/COSMOS.git

# Download and setup COSMOS devel area
RUN gem install bundler --no-document
RUN cd /devel \
  && git clone -b cosmos4 ${COSMOS_REPO} COSMOS \
  && cd /devel/COSMOS \
  && bundle install

ARG COSMOS_DOCKER_REPO=https://github.com/BallAerospace/cosmos-docker.git

# Download COSMOS docker files to support docker release
RUN cd /devel \
  && git clone ${COSMOS_DOCKER_REPO}

ENV COSMOS_DEVEL /devel/COSMOS
ENV COSMOS_NO_SIMPLECOV 1
ENV DOCKER 1
WORKDIR /devel/COSMOS
CMD bash
