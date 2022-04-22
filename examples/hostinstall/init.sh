#!/bin/sh
# set -x

# Start Redis
redis-server /config/redis.conf &

# Start Minio
export MINIO_ROOT_USER=${COSMOS_MINIO_USERNAME}
export MINIO_ROOT_PASSWORD=${COSMOS_MINIO_PASSWORD}
mkdir ~/minio
minio server ~/minio &

# Wait for Redis and Minio to be up
RC=1
while [ $RC -gt 0 ]; do
    curl -fs ${COSMOS_S3_URL}/minio/health/live -o /dev/null
    RC=$?
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} waiting for Minio ${COSMOS_S3_URL} RC: ${RC}";
    sleep 1
done

RC=1
while [ $RC -gt 0 ]; do
    printf "AUTH healthcheck nopass\r\nPING\r\n" | nc -w 2 ${COSMOS_REDIS_HOSTNAME} ${COSMOS_REDIS_PORT} | grep -q 'PONG'
    RC=$?
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} waiting for Redis. RC: ${RC}";
    sleep 1
done

# Configure Minio
mc alias set cosmosminio "${COSMOS_S3_URL}" ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD} || exit 1

# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add cosmosminio script /config/script-runner.json || exit 1

# Create a new user scriptrunner on MinIO use mc admin user.
mc admin user add cosmosminio ${COSMOS_SR_MINIO_USERNAME} ${COSMOS_SR_MINIO_PASSWORD} || exit 1

# Once the user is successfully created you can now apply the getonly policy for this user.
mc admin policy set cosmosminio script user=${COSMOS_SR_MINIO_USERNAME} || exit 1

# Start cmd-tlm-api
cd /home/cosmos/COSMOS/cosmos-cmd-tlm-api && rails s -b 0.0.0.0 -p 2901 &

sleep 10

# Install Plugins
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-base-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-cmdtlmserver-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-limitsmonitor-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-cmdsender-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-scriptrunner-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-packetviewer-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-tlmviewer-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-tlmgrapher-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-dataextractor-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-dataviewer-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-tablemanager-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-admin-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-calendar-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-tool-autonomic-${RVERSION}.*.gem || exit 1
ruby /home/cosmos/COSMOS/cosmos/bin/cosmos load /home/cosmos/COSMOS/cosmos-init/plugins/gems/cosmosc2-demo-${RVERSION}.*.gem || exit 1

# Start script-runner-api
cd /home/cosmos/COSMOS/cosmos-script-runner-api && rails s -b 0.0.0.0 -p 2902 &

# Start cosmos-operator
cd /cosmos/lib/cosmos/operators/ && ruby microservice_operator.rb &

# Start cosmos-traefik
cd /opt/traefik && ./traefik
