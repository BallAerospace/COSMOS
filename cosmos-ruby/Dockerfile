FROM alpine:3.14.1

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

RUN apk update \
  && apk add ruby \
    ruby-etc \
    ruby-bigdecimal \
    ruby-io-console \
    ruby-irb \
    ca-certificates \
    libressl \
    less \
    tini \
    git \
    libxml2-dev \
    libxslt-dev \
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
