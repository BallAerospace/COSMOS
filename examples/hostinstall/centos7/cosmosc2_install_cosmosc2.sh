#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./cosmosc2_env.sh

export USER=`whoami`

# Create gems folder for COSMOS to install gems to
sudo mkdir /gems && sudo chown $USER:$USER /gems

# COSMOS Containerized apps expect the cosmos libraries to be at /cosmos
sudo cp -r $SCRIPT_DIR/../../../cosmos /cosmos

cd /cosmos

sudo mkdir -p lib/cosmos/ext
sudo -E bundle config set --local without 'development'
sudo -E bundle install --quiet
sudo -E bundle exec rake build

cd $SCRIPT_DIR/../../../cosmos-cmd-tlm-api

sudo -E bundle config set --local without 'development'
sudo -E bundle install --quiet

cd $SCRIPT_DIR/../../../cosmos-script-runner-api

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

cd $SCRIPT_DIR/../../../cosmos-init/plugins/

yarn config set registry $NPM_URL
yarn

PLUGINS="$SCRIPT_DIR/../../../cosmos-init/plugins/"
GEMS="$SCRIPT_DIR/../../../cosmos-init/plugins/gems/"
COSMOS_RELEASE_VERSION=5.0.5

mkdir -p ${GEMS}
cd ${PLUGINS}cosmosc2-tool-base && yarn install && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-admin && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-cmdsender && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-cmdtlmserver && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-dataextractor && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-dataviewer && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-handbooks && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-limitsmonitor && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-packetviewer && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-scriptrunner && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-calendar && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-tablemanager && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-tlmgrapher && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-tlmviewer && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-tool-autonomic && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
cd ${PLUGINS}packages/cosmosc2-demo && yarn run build && rake build VERSION=${COSMOS_RELEASE_VERSION} && mv *.gem ${GEMS}
