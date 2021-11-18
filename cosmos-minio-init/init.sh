#!/bin/sh
# set -ex

uname -a

mc --version

# Use mc admin policy to create canned policies. Server provides a default set
# of canned policies namely writeonly, readonly and readwrite (these policies
# apply to all resources on the server). These can be overridden by custom
# policies using mc admin policy command.

if [ -z "${COSMOS_S3_URL}" ]; then
  COSMOS_S3_URL='http://cosmos-minio:9000'
fi

RC=1
if [ ! -z "${COSMOS_ISTIO_ENABLED}" ]; then
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} COSMOS_ISTIO_ENABLED enabled."
    while [ $RC -gt 0 ]; do
        curl -fs "http://localhost:15021/healthz/ready" -o /dev/null
        RC=$?
        T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${T} waiting for sidecar... RC: ${RC}"
        sleep 3
    done
    echo "Sidecar available. Running the command..."
fi

RC=1
while [ $RC -gt 0 ]; do
    curl -fs "${COSMOS_S3_URL}/minio/health/live" -o /dev/null
    RC=$?
    T=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${T} waiting for Minio ${COSMOS_S3_URL} RC: ${RC}"
    sleep 1
done

mc alias set cosmosminio "${COSMOS_S3_URL}" ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD} || exit 1

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add cosmosminio script ${DIR}/script-runner.json || exit 1

# Create a new user scriptrunner on MinIO use mc admin user.

mc admin user add cosmosminio ${COSMOS_SR_MINIO_USERNAME} ${COSMOS_SR_MINIO_PASSWORD} || exit 1

# Once the user is successfully created you can now apply the getonly policy for this user.

mc admin policy set cosmosminio script user=${COSMOS_SR_MINIO_USERNAME} || exit 1

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
