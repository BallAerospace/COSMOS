#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./openc3_env.sh

export USER=`whoami`

# Create gems folder for OpenC3 to install gems to
sudo mkdir /gems && sudo chown $USER:$USER /gems

# OpenC3 Containerized apps expect the openc3 libraries to be at /openc3
sudo cp -r $SCRIPT_DIR/../../../openc3 /openc3

cd /openc3

sudo mkdir -p lib/openc3/ext
sudo -E bundle config set --local without 'development'
sudo -E bundle install --quiet
sudo -E bundle exec rake build

cd $SCRIPT_DIR/../../../openc3-cmd-tlm-api

sudo -E bundle config set --local without 'development'
sudo -E bundle install --quiet

cd $SCRIPT_DIR/../../../openc3-script-runner-api

sudo -E bundle config set --local without 'development'
sudo -E bundle install --quiet

if [ -f "/etc/centos-release" ]; then
  sudo yum install epel-release -y || true
else
  sudo subscription-manager repos --enable rhel-*-optional-rpms \
                           --enable rhel-*-extras-rpms \
                           --enable rhel-ha-for-rhel-*-server-rpms
  sudo subscription-manager repos --disable=rhel-7-server-e4s-optional-rpms --disable=rhel-7-server-eus-optional-rpms
  sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || true
fi
sudo yum install nodejs npm -y
sudo npm install --global yarn

cd $SCRIPT_DIR/../../../openc3-init/plugins/

yarn config set registry $NPM_URL
yarn

PLUGINS="$SCRIPT_DIR/../../../openc3-init/plugins/"
GEMS="$SCRIPT_DIR/../../../openc3-init/plugins/gems/"
OPENC3_RELEASE_VERSION=5.0.6-beta0

mkdir -p ${GEMS}
cd ${PLUGINS}openc3-tool-base && yarn install && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-admin && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-cmdsender && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-cmdtlmserver && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-dataextractor && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-dataviewer && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-handbooks && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-limitsmonitor && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-packetviewer && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-scriptrunner && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-calendar && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-tablemanager && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-tlmgrapher && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-tlmviewer && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-tool-autonomic && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/openc3-demo && yarn run build && rake build VERSION=${OPENC3_RELEASE_VERSION} && mv *.gem ${GEMS}
