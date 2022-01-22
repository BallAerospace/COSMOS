FROM alpine:3.15.0
ARG APK_URL
ARG RUBYGEMS_URL
# Persist the RUBYGEMS_URL ARG in a ENV for the Gemfiles to use
ENV RUBYGEMS_URL=${RUBYGEMS_URL}
# NOTE: This must match the alpine image used above in FROM
RUN echo "$APK_URL/alpine/v3.15/main" > /etc/apk/repositories \
  && echo "$APK_URL/alpine/v3.15/community" >> /etc/apk/repositories

LABEL maintainer="cosmos@ballaerospace.com"

# We require a local certificate file so set that up.
# You must place a valid cert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=1

ADD gemrc /root/.gemrc
RUN sed -i "s|RUBYGEMS_URL|$RUBYGEMS_URL|g" /root/.gemrc

RUN apk update \
  && apk add ruby \
  ruby-etc \
  ruby-bigdecimal \
  ruby-io-console \
  ruby-irb \
  ca-certificates \
  curl \
  libressl \
  less \
  tini \
  git \
  libxml2-dev \
  libxslt-dev \
  && gem update --system 3.3.5 \
  && gem install bundler || apk add ruby-bundler \
  && gem install rake || apk add ruby-rake \
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
