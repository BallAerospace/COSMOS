#!/bin/sh
set -e

PLUGINS="/cosmos/plugins"
PACKAGES="packages"
RVERSION="5.0.0"

packageBuild() {
  echo "<<< packageBuild $1"
  cd ${PLUGINS}/${PACKAGES}/${1}/
  npm run --silent build
  echo "--- packageBuild $1 npm run build complete"
  rake build VERSION=${RVERSION}
  echo "--- packageBuild $1 rake build complete"
}

packageInstall() {
  echo "<<< packageInstall $1"
  cd ${PLUGINS}/${1}/
  echo "--- packageInstall $1 npm install"
  npm install --silent
  echo "--- packageInstall $1 npm install complete"
  echo "--- packageInstall $1 npm build"
  npm run --silent build
  echo "--- packageInstall $1 npm run build complete"
  echo "--- packageInstall $1 rake build"
  rake build VERSION=${RVERSION}
  echo "--- packageInstall $1 rake build complete"
}

packageInstall cosmosc2-tool-base

packageBuild cosmosc2-tool-admin
packageBuild cosmosc2-tool-cmdsender
packageBuild cosmosc2-tool-cmdtlmserver
packageBuild cosmosc2-tool-dataextractor
packageBuild cosmosc2-tool-dataviewer
packageBuild cosmosc2-tool-limitsmonitor
packageBuild cosmosc2-tool-packetviewer
packageBuild cosmosc2-tool-scriptrunner
packageBuild cosmosc2-tool-tlmgrapher
packageBuild cosmosc2-tool-tlmviewer
