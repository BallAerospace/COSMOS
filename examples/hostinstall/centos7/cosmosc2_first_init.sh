#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd SCRIPT_DIR
source ./cosmosc2_env.sh

# Configure Minio
mc alias set cosmosminio "${COSMOS_S3_URL}" ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD} || exit 1

# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add cosmosminio script $SCRIPT_DIR/../../../cosmos-minio-init/script-runner.json || exit 1

# Create a new user scriptrunner on MinIO use mc admin user.
mc admin user add cosmosminio ${COSMOS_SR_MINIO_USERNAME} ${COSMOS_SR_MINIO_PASSWORD} || exit 1

# Once the user is successfully created you can now apply the getonly policy for this user.
mc admin policy set cosmosminio script user=${COSMOS_SR_MINIO_USERNAME} || exit 1

export RVERSION=5.0.1

# Install Plugins
mkdir -p /tmp/cosmos/tmp/tmp
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-base-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-cmdtlmserver-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-limitsmonitor-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-cmdsender-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-scriptrunner-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-packetviewer-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-tlmviewer-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-tlmgrapher-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-dataextractor-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-dataviewer-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-tablemanager-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-admin-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-calendar-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-tool-autonomic-${RVERSION}.*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /cosmos/bin/cosmos load $SCRIPT_DIR/../../../cosmos-init/plugins/gems/cosmosc2-demo-${RVERSION}.*.gem || exit 1

# Sleep To Keep Process Alive - Ctrl-C when done
echo "Sleep until Ctrl-C to Keep Process Alive"
sleep 1000000000

cd ~/
