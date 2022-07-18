#!/bin/sh
set -x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./openc3_env.sh

# Start Redis
redis-server /config/redis.conf &
redis-server /config/redis_ephemeral.conf &

# Start Minio
export MINIO_ROOT_USER=${OPENC3_MINIO_USERNAME}
export MINIO_ROOT_PASSWORD=${OPENC3_MINIO_PASSWORD}
mkdir -p ~/minio
minio server --console-address ":9090" ~/minio &

# Wait for Redis and Minio to be up
echo "30 Second Delay to Allow Startup"
sleep 30

# Start cmd-tlm-api
cd $SCRIPT_DIR/../../../openc3-cmd-tlm-api && rails s -b 0.0.0.0 -p 2901 &

# Start script-runner-api
cd $SCRIPT_DIR/../../../openc3-script-runner-api && rails s -b 0.0.0.0 -p 2902 &

# Start openc3-operator
cd /openc3/lib/openc3/operators/ && ruby microservice_operator.rb &

# Start openc3-traefik
cd /opt/traefik && ./traefik &

cd ~/
