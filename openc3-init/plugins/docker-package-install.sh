#!/bin/sh
set -e

PLUGINS="/openc3/plugins"
GEMS="/openc3/plugins/gems/"
PACKAGES="packages"
OPENC3_RELEASE_VERSION=5.0.6-beta0

mkdir -p ${GEMS}

echo "<<< packageInstall $1"
cd ${PLUGINS}/${1}/
echo "--- packageInstall $1 yarn install"
yarn install
echo "=== packageInstall $1 yarn install complete"
echo "--- packageInstall $1 yarn build"
yarn run build
echo "=== packageInstall $1 yarn run build complete"
echo "--- packageInstall $1 rake build"
rake build VERSION=${OPENC3_RELEASE_VERSION}
echo "=== packageInstall $1 rake build complete"
ls *.gem
echo "--- packageInstall $1 mv gem file"
mv ${1}-*.gem ${GEMS}
echo "=== packageInstall $1 mv gem complete"