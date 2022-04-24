#!/bin/sh
set -x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./cosmosc2_env.sh

# Start Redis
redis-server /config/redis.conf &

# Start Minio
export MINIO_ROOT_USER=${COSMOS_MINIO_USERNAME}
export MINIO_ROOT_PASSWORD=${COSMOS_MINIO_PASSWORD}
mkdir -p ~/minio
minio server --console-address ":9090" ~/minio &

# Wait for Redis and Minio to be up
echo "30 Second Delay to Allow Startup"
sleep 30

# Start cmd-tlm-api
cd $SCRIPT_DIR/../../../cosmos-cmd-tlm-api && rails s -b 0.0.0.0 -p 2901 &

# Start script-runner-api
cd $SCRIPT_DIR/../../../cosmos-script-runner-api && rails s -b 0.0.0.0 -p 2902 &

# Start cosmos-operator
cd /cosmos/lib/cosmos/operators/ && ruby microservice_operator.rb &

# Start cosmos-traefik
cd /opt/traefik && ./traefik &

cd ~/
