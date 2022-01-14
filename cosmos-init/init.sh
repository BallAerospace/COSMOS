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
fi

ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-base-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdtlmserver-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-limitsmonitor-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdsender-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-scriptrunner-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-packetviewer-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmviewer-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmgrapher-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataextractor-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataviewer-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tablemanager-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-admin-5.0.1.*.gem || exit 1
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-timeline-5.0.1.*.gem || exit 1

if [ ! -z $COSMOS_DEMO ]; then
    ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-demo-5.0.1.*.gem || exit 1
fi

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
