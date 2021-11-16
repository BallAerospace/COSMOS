#!/bin/sh
set -e

uname -a

mc --version

# Use mc admin policy to create canned policies. Server provides a default set
# of canned policies namely writeonly, readonly and readwrite (these policies
# apply to all resources on the server). These can be overridden by custom
# policies using mc admin policy command.

if [ -z "${COSMOS_S3_URL}" ]; then
  COSMOS_S3_URL='http://cosmos-minio:9000'
fi

mc alias set cosmosminio ${COSMOS_S3_URL} ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD}

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Create new canned policy by name script using script-runner.json policy file.
mc admin policy add cosmosminio script ${DIR}/script-runner.json

# Create a new user scriptrunner on MinIO use mc admin user.

mc admin user add cosmosminio ${COSMOS_SR_MINIO_USERNAME} ${COSMOS_SR_MINIO_PASSWORD}

# Once the user is successfully created you can now apply the getonly policy for this user.

mc admin policy set cosmosminio script user=${COSMOS_SR_MINIO_USERNAME}
