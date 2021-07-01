#!/bin/sh
set -e

PLUGINS="/cosmos/plugins"
GEMS="/cosmos/plugins/gems/"
PACKAGES="packages"
RVERSION="5.0.0"

mkdir -p ${GEMS}

echo "<<< packageInstall $1"
cd ${PLUGINS}/${1}/
echo "--- packageInstall $1 yarn install"
yarn install --silent
echo "=== packageInstall $1 yarn install complete"
echo "--- packageInstall $1 yarn build"
yarn run --silent build
echo "=== packageInstall $1 yarn run build complete"
echo "--- packageInstall $1 rake build"
rake build VERSION=${RVERSION}
echo "=== packageInstall $1 rake build complete"
ls *.gem
echo "--- packageInstall $1 mv gem file"
mv ${1}-*.gem ${GEMS}
echo "=== packageInstall $1 mv gem complete"