#!/bin/sh
# set -x

if [ -z "${COSMOS_S3_URL}" ]; then
  COSMOS_S3_URL='http://cosmos-minio:9000'
fi

RC=1
if [ ! -z "${COSMOS_ISTIO_ENABLED}" ]; then
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} COSMOS_ISTIO_ENABLED enabled."
    while [ $RC -gt 0 ]; do
        curl -fs http://localhost:15021/healthz/ready -o /dev/null
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for sidecar. RC: ${RC}"
        sleep 1
    done
    echo "Sidecar available. Running the command..."
fi

RC=1
while [ $RC -gt 0 ]; do
    curl -fs ${COSMOS_S3_URL}/minio/health/live -o /dev/null
    RC=$?
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} waiting for Minio ${COSMOS_S3_URL} RC: ${RC}";
    sleep 1
done

RC=1
if [ -z "${COSMOS_REDIS_CLUSTER}" ]; then
    while [ $RC -gt 0 ]; do
        printf "AUTH healthcheck nopass\r\nPING\r\n" | nc -w 2 ${COSMOS_REDIS_HOSTNAME} ${COSMOS_REDIS_PORT} | grep -q 'PONG'
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for Redis. RC: ${RC}";
        sleep 1
    done
else
    while [ $RC -gt 0 ]; do
        printf "AUTH healthcheck nopass\r\nCLUSTER INFO\r\n" | nc -w 2 ${COSMOS_REDIS_HOSTNAME} ${COSMOS_REDIS_PORT} | grep -q 'cluster_state:ok'
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for Redis. RC: ${RC}";
        sleep 1
    done
    while [ $RC -gt 0 ]; do
        printf "AUTH healthcheck nopass\r\nCLUSTER INFO\r\n" | nc -w 2 ${COSMOS_REDIS_EPHEMERAL_HOSTNAME} ${COSMOS_REDIS_EPHEMERAL_PORT} | grep -q 'cluster_state:ok'
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for Redis. RC: ${RC}";
        sleep 1
    done
fi

# Fail on errors
set -e

mc alias set cosmosminio "${COSMOS_S3_URL}" ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD} || exit 1

# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add cosmosminio script /cosmos/minio/script-runner.json || exit 1

# Create a new user scriptrunner on MinIO use mc admin user.
mc admin user add cosmosminio ${COSMOS_SR_MINIO_USERNAME} ${COSMOS_SR_MINIO_PASSWORD} || exit 1

# Once the user is successfully created you can now apply the getonly policy for this user.
mc admin policy set cosmosminio script user=${COSMOS_SR_MINIO_USERNAME} || exit 1

ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-base-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdtlmserver-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-limitsmonitor-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdsender-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-scriptrunner-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-packetviewer-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmviewer-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmgrapher-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataextractor-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataviewer-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-handbooks-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tablemanager-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-admin-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-calendar-*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-autonomic-*.gem || exit 1

if [ ! -z $COSMOS_DEMO ]; then
    ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-demo-*.gem || exit 1
fi

# Need to allow errors during this wait
set +e

RC=1
if [ ! -z "${COSMOS_ISTIO_ENABLED}" ]; then
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} COSMOS_ISTIO_ENABLED enabled. Calling quitquitquit..."
    while [ $RC -gt 0 ]; do
        curl -fs -X POST http://localhost:15020/quitquitquit -o /dev/null
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for sidecar quit. RC: ${RC}"
    done
fi

T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${T} all done."
