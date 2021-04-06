#!/usr/bin/env bash
# Please see cosmos_setup.sh

# exit when any command fails
set -e

# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker network inspect cosmos || docker network create cosmos

docker build -f cosmos/Dockerfile -t cosmos-base cosmos

docker container rm cosmos-gems || true
docker volume create cosmos-gems-v
docker run --network cosmos -p 127.0.0.1:9292:9292 -d --name cosmos-gems -v cosmos-gems-v:/data cosmos-gems

if [[ "$1" == "dev" ]]; then
  docker container rm cosmos-elasticsearch || true
  docker volume create cosmos-elasticsearch-v
  docker pull amazon/opendistro-for-elasticsearch:1.12.0
  docker build -f elasticsearch/Dockerfile -t cosmos-elasticsearch elasticsearch
  docker run --network cosmos -p 127.0.0.1:9200:9200 -d --name cosmos-elasticsearch -v cosmos-elasticsearch-v:/usr/share/elasticsearch/data -e "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 --env discovery.type="single-node" --env ES_JAVA_OPTS="-Xms1g -Xmx1g" --env MALLOC_ARENA_MAX=4  cosmos-elasticsearch

  docker container rm cosmos-kibana || true
  docker pull amazon/opendistro-for-elasticsearch-kibana:1.12.0
  docker build -f kibana/Dockerfile -t cosmos-kibana kibana
  docker run --network cosmos -p 127.0.0.1:5601:5601 -d --name cosmos-kibana --env ELASTICSEARCH_HOSTS=http://cosmos-elasticsearch:9200 cosmos-kibana
  echo "Kibana at http://localhost:5601/"

  docker container rm cosmos-prometheus || true
  docker pull prom/prometheus:v2.24.1
  docker build -f prometheus/Dockerfile -t cosmos-prometheus prometheus
  docker run --network cosmos -p 127.0.0.1:9090:9090 -d --name cosmos-prometheus cosmos-prometheus
  echo "Prometheus at http://localhost:9090/"

  docker container rm cosmos-grafana || true
  docker volume create cosmos-grafana-v
  docker build -f grafana/Dockerfile -t cosmos-grafana grafana
  docker run --network cosmos -p 0.0.0.0:3000:3000 -d --name cosmos-grafana -v cosmos-grafana-v:/var/lib/grafana --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=grafana.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true cosmos-grafana
  echo "Grafana http://localhost:3000/"

  docker container rm cosmos-fluentd || true
  docker build -f fluentd/Dockerfile -t cosmos-fluentd fluentd
  docker run --network cosmos -p 127.0.0.1:24224:24224 -p 127.0.0.1:24224:24224/udp -d --name cosmos-fluentd cosmos-fluentd
  sleep 30
  curl -X POST http://localhost:5601/api/saved_objects/_import -H "kbn-xsrf:true" --form file=@kibana/export.ndjson -w "\n"
fi

docker container rm cosmos-redis || true
docker volume create cosmos-redis-v
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --name cosmos-redis -v cosmos-redis-v:/data redis:6.2 redis-server --appendonly yes

docker container rm cosmos-minio || true
docker volume create cosmos-minio-v
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --name cosmos-minio -v cosmos-minio-v:/data minio/minio:RELEASE.2020-08-25T00-21-20Z server /data
sleep 30

docker container rm cosmos-cmd-tlm-api || true
docker build -f cmd_tlm_api/Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api
docker run --network cosmos -p 127.0.0.1:2901:2901 -d --name cosmos-cmd-tlm-api cosmos-cmd-tlm-api

docker container rm cosmos-script-runner-api || true
docker build -f script_runner_api/Dockerfile -t cosmos-script-runner-api script_runner_api
docker run --network cosmos -p 127.0.0.1:2902:2902 -d --name cosmos-script-runner-api cosmos-script-runner-api

docker container rm cosmos-operator || true
docker build -f operator/Dockerfile -t cosmos-operator operator
docker run --network cosmos -d --name cosmos-operator cosmos-operator

docker container rm cosmos-traefik || true
docker build -f traefik/Dockerfile -t cosmos-traefik traefik
docker run --network cosmos -p 127.0.0.1:2900:80 -d --name cosmos-traefik cosmos-traefik

docker build -f frontend/Dockerfile -t cosmos-frontend-init frontend
docker run --network cosmos --name cosmos-frontend-init --rm cosmos-frontend-init

docker build -f init/Dockerfile -t cosmos-init init
docker run --network cosmos --name cosmos-init --rm cosmos-init

echo "If everything is working you should be able to access Cosmos at http://localhost:2900/"