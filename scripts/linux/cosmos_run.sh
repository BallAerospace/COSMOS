#!/usr/bin/env bash
# Please see cosmos_setup.sh

# exit when any command fails
set -e

# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker network inspect cosmos || docker network create cosmos

docker container rm cosmos-redis || true
docker volume create cosmos-redis-v
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --name cosmos-redis -v cosmos-redis-v:/data redis:6.2 redis-server --appendonly yes

docker container rm cosmos-minio || true
docker volume create cosmos-minio-v
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --name cosmos-minio -v cosmos-minio-v:/data minio/minio:RELEASE.2020-08-25T00-21-20Z server /data
sleep 30

docker container rm cosmos-cmd-tlm-api || true
docker run --network cosmos -p 127.0.0.1:2901:2901 -d --name cosmos-cmd-tlm-api cosmos-cmd-tlm-api

docker container rm cosmos-script-runner-api || true
docker run --network cosmos -p 127.0.0.1:2902:2902 -d --name cosmos-script-runner-api cosmos-script-runner-api

docker container rm cosmos-operator || true
docker run --network cosmos -d --name cosmos-operator cosmos-operator

docker container rm cosmos-traefik || true
docker run --network cosmos -p 127.0.0.1:2900:80 -d --name cosmos-traefik cosmos-traefik

docker run --network cosmos --name cosmos-frontend-init --rm cosmos-frontend-init
docker run --network cosmos --name cosmos-init --rm cosmos-init

echo "If everything is working you should be able to access Cosmos at http://localhost:2900/"
