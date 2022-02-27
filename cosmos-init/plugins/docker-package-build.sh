#!/bin/sh
set -e

PLUGINS="/cosmos/plugins"
GEMS="/cosmos/plugins/gems/"
PACKAGES="packages"
RVERSION="5.0.1"

mkdir -p ${GEMS}

echo "<<< packageBuild $1"
cd ${PLUGINS}/${PACKAGES}/${1}/
echo "--- packageBuild $1 yarn run build"
yarn run build
echo "=== packageBuild $1 yarn run build complete"
echo "--- packageBuild $1 rake build"
rake build VERSION=${RVERSION}
echo "=== packageBuild $1 rake build complete"
ls *.gem
echo "--- packageInstall $1 mv gem file"
mv ${1}-*.gem ${GEMS}
echo "=== packageInstall $1 mv gem complete"