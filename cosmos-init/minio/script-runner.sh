#!/bin/sh
set -e

# Use mc admin policy to create canned policies. Server provides a default set
# of canned policies namely writeonly, readonly and readwrite (these policies
# apply to all resources on the server). These can be overridden by custom
# policies using mc admin policy command.

mc alias set cosmosminio http://cosmos-minio:9000 ${COSMOS_MINIO_USERNAME} ${COSMOS_MINIO_PASSWORD}

# Create new canned policy by name script using script-runner.json policy file.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mc admin policy add cosmosminio script ${dir}/script-runner.json

# Create a new user scriptrunner on MinIO use mc admin user.

mc admin user add cosmosminio ${COSMOS_MINIO_SCRIPT_RUNNER_USERNAME} ${COSMOS_MINIO_SCRIPT_RUNNER_PASSWORD}

# Once the user is successfully created you can now apply the getonly policy for this user.

mc admin policy set cosmosminio script user=${COSMOS_MINIO_SCRIPT_RUNNER_USERNAME}
