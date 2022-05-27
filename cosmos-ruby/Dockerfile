# Make managed in .env-build
ARG COSMOS_REGISTRY=docker.io
ARG ALPINE_BUILD
ARG ALPINE_VERSION

# Should be loaded from ARG
FROM ${COSMOS_REGISTRY}/alpine:${ALPINE_VERSION}.${ALPINE_BUILD}

# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. So we need to re-ARG ALPINE_VERSION

ARG ALPINE_VERSION
ARG APK_URL
ARG RUBYGEMS_URL

ENV ALPINE_VERSION=${ALPINE_VERSION}
ENV APK_URL=${APK_URL}
ENV RUBYGEMS_URL=${RUBYGEMS_URL}

# NOTE: This must match the alpine image used above in FROM
RUN echo "${APK_URL}/alpine/v${ALPINE_VERSION}/main" > /etc/apk/repositories \
  && echo "${APK_URL}/alpine/v${ALPINE_VERSION}/community" >> /etc/apk/repositories

LABEL maintainer="cosmos@ballaerospace.com"

# We require a local certificate file so set that up.
# You must place a valid cacert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem
ENV NODE_EXTRA_CA_CERTS=/devel/cacert.pem

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=1

ADD .gemrc /root/.gemrc
RUN sed -i "s|RUBYGEMS_URL|${RUBYGEMS_URL}|g" /root/.gemrc
RUN cp /root/.gemrc /etc/.gemrc

RUN apk update \
  && apk add ruby \
  build-base \
  ruby-dev \
  libressl-dev \
  ruby-etc \
  ruby-bigdecimal \
  ruby-io-console \
  ruby-irb \
  ca-certificates \
  curl \
  libc6-compat \
  libressl \
  less \
  tini \
  git \
  libxml2-dev \
  libxslt-dev \
  && gem update --system 3.3.14 \
  && gem install rake \
  && gem cleanup \
  && bundle config build.nokogiri --use-system-libraries \
  && bundle config git.allow_insecure true

# Set user and group
ENV IMAGE_USER=cosmos
ENV IMAGE_GROUP=cosmos
ENV USER_ID=1000
ENV GROUP_ID=1000
RUN addgroup -g ${GROUP_ID} -S ${IMAGE_GROUP}
RUN adduser -u ${USER_ID} -G ${IMAGE_GROUP} -s /bin/ash -S ${IMAGE_USER}

# Switch to user
USER ${USER_ID}:${GROUP_ID}

ENTRYPOINT [ "/sbin/tini", "--" ]
