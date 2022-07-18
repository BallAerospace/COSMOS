#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./openc3_env.sh

# Configure Minio
mc alias set openc3minio "${OPENC3_S3_URL}" ${OPENC3_MINIO_USERNAME} ${OPENC3_MINIO_PASSWORD} || exit 1

# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add openc3minio script $SCRIPT_DIR/../../../openc3-init/script-runner.json || exit 1

# Create a new user scriptrunner on MinIO use mc admin user.
mc admin user add openc3minio ${OPENC3_SR_MINIO_USERNAME} ${OPENC3_SR_MINIO_PASSWORD} || exit 1

# Once the user is successfully created you can now apply the getonly policy for this user.
mc admin policy set openc3minio script user=${OPENC3_SR_MINIO_USERNAME} || exit 1

# Install Plugins
mkdir -p /tmp/openc3/tmp/tmp
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-base-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-cmdtlmserver-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-limitsmonitor-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-cmdsender-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-scriptrunner-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-packetviewer-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-tlmviewer-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-tlmgrapher-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-dataextractor-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-dataviewer-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-handbooks-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-tablemanager-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-admin-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-calendar-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-tool-autonomic-*.gem || exit 1
sudo -E --preserve-env=RUBYLIB /openc3/bin/openc3cli load $SCRIPT_DIR/../../../openc3-init/plugins/gems/openc3-demo-*.gem || exit 1

# Sleep To Keep Process Alive - Ctrl-C when done
echo "Sleep until Ctrl-C to Keep Process Alive"
sleep 1000000000

cd ~/
