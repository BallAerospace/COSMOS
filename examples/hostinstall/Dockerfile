# WARNING: This Dockerfile is only to show that COSMOS 5 can be run outside of containerized environments
# This is not a supported configuration, this file is not maintained, and should not be used beyond proof of concept
# If you were going to do this, at a minimum the additional changes would need to be made:
#   1. Processes in init.sh should be setup as services that restart on reboot
#   2. Processes should not be run as root
#   3. Permissions should be set so that the cmd-tlm-api can install 3rd party gems for plugins
# IN SUMMARY: RUN COSMOS IN DOCKER/PODMAN - DO NOT USE THIS FILE

FROM centos:7

RUN yum update -y && yum install -y \
  gcc \
  gcc-c++ \
  gdbm-devel \
  git \
  iproute \
  libyaml-devel \
  libffi-devel \
  make \
  ncurses-devel \
  net-tools \
	nc \
	openssl-devel \
  readline-devel \
	shadow-utils \
  wget \
  zlib-devel

# We require a local certificate file so set that up.
# You must place a valid cacert.pem file in your COSMOS development folder for this work
# Comment out these lines if this is not required in your environment
COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=1

ENV RUBYGEMS_URL=https://rubygems.org
ENV NPM_URL=https://registry.npmjs.org

ENV SECRET_KEY_BASE=bdb4300d46c9d4f116ce3dbbd54cac6b20802d8be1c2333cf5f6f90b1627799ac5d043e8460744077bc0bd6aacdd5c4bf53f499a68303c6752e7f327b874b96a
ENV COSMOS_REDIS_HOSTNAME=localhost
ENV COSMOS_REDIS_PORT=6379
ENV COSMOS_S3_URL=http://localhost:9000

ENV COSMOS_REDIS_USERNAME=cosmos
ENV COSMOS_REDIS_PASSWORD=cosmospassword

ENV COSMOS_MINIO_USERNAME=cosmosminio
ENV COSMOS_MINIO_PASSWORD=cosmosminiopassword

ENV COSMOS_SERVICE_PASSWORD=cosmosservice

ENV COSMOS_SR_REDIS_USERNAME=scriptrunner
ENV COSMOS_SR_REDIS_PASSWORD=scriptrunnerpassword
ENV COSMOS_SR_MINIO_USERNAME=scriptrunnerminio
ENV COSMOS_SR_MINIO_PASSWORD=scriptrunnerminiopassword

ENV COSMOS_TAG=latest
ENV COSMOS_VERSION=5.0.2.beta

ENV COSMOS_DEMO=1

ADD gemrc /root/.gemrc
RUN sed -i "s|RUBYGEMS_URL|${RUBYGEMS_URL}|g" /root/.gemrc

# Only ruby 2.0 in Centos7 so build from source

# START MODIFIED CONTENT FROM OFFICIAL RUBY DOCKERFILE

# skip installing gem documentation
RUN set -eux; \
	mkdir -p /usr/local/etc; \
	{ \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV LANG C.UTF-8
ENV RUBY_MAJOR 3.0
ENV RUBY_VERSION 3.0.3
ENV RUBY_DOWNLOAD_SHA256 88cc7f0f021f15c4cd62b1f922e3a401697f7943551fe45b1fdf4f2417a17a9c

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
	\
	wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
	echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
	\
	mkdir -p /usr/src/ruby; \
	tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
	rm ruby.tar.xz; \
	\
	cd /usr/src/ruby; \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	{ \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new; \
	mv file.c.new file.c; \
	\
	./configure \
		--disable-install-doc \
		--enable-shared \
	; \
	make -j "$(nproc)"; \
	make install; \
	\
	cd /; \
	rm -r /usr/src/ruby; \
# rough smoke test
	ruby --version; \
	gem --version; \
	bundle --version

RUN gem update --system 3.3.5 \
  && gem install bundler \
  && gem install rake \
  && bundle config build.nokogiri --use-system-libraries \
  && bundle config git.allow_insecure true

# END CONTENT FROM OFFICIAL RUBY DOCKERFILE

# INSTALL REDIS

RUN set -eux; \
        \
        wget -O redis.tar.gz "https://download.redis.io/releases/redis-6.2.6.tar.gz"; \
        echo "5b2b8b7a50111ef395bf1c1d5be11e6e167ac018125055daa8b5c2317ae131ab redis.tar.gz" | sha256sum --check --strict; \
        \
        mkdir -p /usr/src/redis; \
        tar -xzvf redis.tar.gz -C /usr/src/redis --strip-components=1; \
        rm redis.tar.gz; \
        \
        cd /usr/src/redis; \
        \
        make; \
        make install; \
        \
        cd /; \
        rm -r /usr/src/redis;

# INSTALL MINIO

RUN set -eux; \
	\
	cd /usr/bin; \
	wget https://dl.min.io/server/minio/release/linux-amd64/minio; \
	chmod +x minio;

RUN set -eux; \
	\
	cd /usr/bin; \
	wget https://dl.min.io/client/mc/release/linux-amd64/mc; \
	chmod +x mc;

# INSTALL TRAEFIK

ENV TRAEFIK_DOWNLOAD_SHA256 5bf0e79b131b5f893d93c1912681deb1a49badb06218c234e43d3b0f7e3b8588

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
	\
	wget -O traefik.tar.gz "https://github.com/traefik/traefik/releases/download/v2.4.13/traefik_v2.4.13_linux_amd64.tar.gz"; \
	echo "$TRAEFIK_DOWNLOAD_SHA256 *traefik.tar.gz" | sha256sum --check --strict; \
	\
	mkdir -p /opt/traefik; \
	tar -zxvf traefik.tar.gz -C /opt/traefik; \
	rm traefik.tar.gz; 

# Set user and group
ENV IMAGE_USER=cosmos
ENV IMAGE_GROUP=cosmos
ENV USER_ID=1000
ENV GROUP_ID=1000
RUN /usr/sbin/groupadd -g ${GROUP_ID} ${IMAGE_GROUP}
RUN /usr/sbin/useradd -u ${USER_ID} -g ${IMAGE_GROUP} -s /bin/ash ${IMAGE_USER}
RUN mkdir /gems && chown cosmos:cosmos /gems

# Switch to user
USER ${USER_ID}:${GROUP_ID}

# Git COSMOS
RUN cd /home/cosmos && git clone https://github.com/BallAerospace/COSMOS.git

# Switch to root
USER root

RUN cp -r /home/cosmos/COSMOS/cosmos /cosmos

ENV RUBYLIB=/cosmos/lib
ENV COSMOS_PATH="/cosmos"
WORKDIR /cosmos

RUN gem env

RUN mkdir -p lib/cosmos/ext \
  && bundle config set --local without 'development' \
  && bundle install --quiet \
  && bundle exec rake build

WORKDIR /home/cosmos/COSMOS/cosmos-cmd-tlm-api

RUN bundle config set --local without 'development' \
  && bundle install --quiet 

WORKDIR /home/cosmos/COSMOS/cosmos-script-runner-api

RUN bundle config set --local without 'development' \
  && bundle install --quiet 

RUN yum install epel-release -y
RUN yum install nodejs npm -y
RUN npm install --global yarn

WORKDIR /home/cosmos/COSMOS/cosmos-init/plugins/

RUN yarn config set registry $NPM_URL && yarn

ENV PLUGINS="/home/cosmos/COSMOS/cosmos-init/plugins/"
ENV GEMS="/home/cosmos/COSMOS/cosmos-init/plugins/gems/"
ENV RVERSION="5.0.1"

RUN mkdir -p ${GEMS}
RUN cd ${PLUGINS}cosmosc2-tool-base && yarn install && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-admin && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-cmdsender && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-cmdtlmserver && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-dataextractor && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-dataviewer && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-limitsmonitor && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-packetviewer && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-scriptrunner && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-calendar && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-tablemanager && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-tlmgrapher && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-tlmviewer && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-tool-autonomic && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}
RUN cd ${PLUGINS}packages/cosmosc2-demo && yarn run build && rake build VERSION=${RVERSION} && mv *.gem ${GEMS}

COPY config/traefik.yaml /etc/traefik/traefik.yaml
COPY --chown=${IMAGE_USER}:${IMAGE_GROUP} init.sh /usr/src/init.sh
RUN chmod +x /usr/src/init.sh

RUN mkdir /config
COPY ./config/* /config/

CMD [ "/usr/src/init.sh" ]
