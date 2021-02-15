#!/usr/bin/env bash
# Please see cosmos_setup.sh

# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker network create cosmos

docker build -f cosmos/Dockerfile -t cosmos-base cosmos

docker volume create cosmos-gems-v
docker container rm cosmos-gems
docker run --network cosmos -p 127.0.0.1:9292:9292 -d --name cosmos-gems -v cosmos-gems-v:/data cosmos-gems

docker volume create cosmos-redis-v
docker container rm cosmos-redis
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --name cosmos-redis -v cosmos-redis-v:/data redis:6.0.6 redis-server --appendonly yes

docker volume create cosmos-minio-v
docker container rm cosmos-minio
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --name cosmos-minio -v cosmos-minio-v:/data minio/minio:RELEASE.2020-08-25T00-21-20Z server /data
sleep 30

docker build -f cmd_tlm_api/Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api
docker container rm cosmos-cmd-tlm-api
docker run --network cosmos -p 127.0.0.1:7777:7777 -d --name cosmos-cmd-tlm-api --env NO_FLUENTD=1 cosmos-cmd-tlm-api

docker build -f script_runner_api/Dockerfile -t cosmos-script-runner-api script_runner_api
docker container rm cosmos-script-runner-api
docker run --network cosmos -p 127.0.0.1:3001:3001 -d --name cosmos-script-runner-api --env NO_FLUENTD=1 cosmos-script-runner-api

docker build -f frontent/Dockerfile -t cosmos-frontend frontend
docker container rm cosmos-frontend
docker run --network cosmos -p 127.0.0.1:8080:80 -d --name cosmos-frontend --env NO_FLUENTD=1 cosmos-frontend

docker build -f operator/Dockerfile -t cosmos-operator operator
docker container rm cosmos-operator
docker run --network cosmos -d -p 7779:7779 --name cosmos-operator --env NO_FLUENTD=1 cosmos-operator

docker build -f init/Dockerfile -t cosmos-init init
docker container rm cosmos-init
docker run --network cosmos --name cosmos-init --rm --env NO_FLUENTD=1 cosmos-init

echo "If everything is working you should be able to access Cosmos at http://localhost:8080/"