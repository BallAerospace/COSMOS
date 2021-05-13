@echo on
REM Please see cosmos_setup.bat

REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b

docker network inspect cosmos || docker network create cosmos || exit /b

docker build -f cosmos-ruby\Dockerfile -t cosmos-ruby cosmos-ruby || exit /b
docker build -f cosmos-node\Dockerfile -t cosmos-node cosmos-node || exit /b
docker build -f cosmos/Dockerfile -t cosmos-base cosmos || exit /b

@echo off
if "%1" == "dev" (
  @echo on
  docker container rm cosmos-elasticsearch
  docker volume create cosmos-elasticsearch-v || exit /b
  docker pull amazon/opendistro-for-elasticsearch:1.12.0 || exit /b
  docker build -f elasticsearch\Dockerfile -t cosmos-elasticsearch elasticsearch || exit /b
  docker run --network cosmos -p 127.0.0.1:9200:9200 -d --name cosmos-elasticsearch -v cosmos-elasticsearch-v:/usr/share/elasticsearch/data -e "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 --env discovery.type="single-node" --env ES_JAVA_OPTS="-Xms1g -Xmx1g" --env MALLOC_ARENA_MAX=4  cosmos-elasticsearch || exit /b

  docker container rm cosmos-kibana
  docker pull amazon/opendistro-for-elasticsearch-kibana:1.12.0 || exit /b
  docker build -f kibana\Dockerfile -t cosmos-kibana kibana || exit /b
  docker run --network cosmos -p 127.0.0.1:5601:5601 -d --name cosmos-kibana --env ELASTICSEARCH_HOSTS=http://cosmos-elasticsearch:9200 cosmos-kibana || exit /b
  REM Kibana at http://localhost:5601/

  docker container rm cosmos-prometheus
  docker pull prom/prometheus:v2.24.1 || exit /b
  docker build -f prometheus\Dockerfile -t cosmos-prometheus prometheus || exit /b
  docker run --network cosmos -p 127.0.0.1:9090:9090 -d --name cosmos-prometheus cosmos-prometheus || exit /b
  REM Prometheus at http://localhost:9090/

  docker container rm cosmos-grafana
  docker volume create cosmos-grafana-v || exit /b
  docker build -f grafana/Dockerfile -t cosmos-grafana grafana || exit /b
  docker run --network cosmos -p 0.0.0.0:3000:3000 -d --name cosmos-grafana -v cosmos-grafana-v:/var/lib/grafana cosmos-grafana || exit /b
  REM Grafana http://localhost:3000/

  docker container rm cosmos-fluentd
  docker build -f fluentd\Dockerfile -t cosmos-fluentd fluentd || exit /b
  docker run --network cosmos -p 127.0.0.1:24224:24224 -p 127.0.0.1:24224:24224/udp -d --name cosmos-fluentd cosmos-fluentd || exit /b
  timeout 30 >nul
  curl -X POST http://localhost:5601/api/saved_objects/_import -H "kbn-xsrf:true" --form file=@kibana\export.ndjson -w "\n" || exit /b
)
@echo on

docker container rm cosmos-redis
docker volume create cosmos-redis-v || exit /b
docker run --network cosmos -p 127.0.0.1:6379:6379 -d --name cosmos-redis -v cosmos-redis-v:/data redis:6.2 redis-server --appendonly yes || exit /b

docker container rm cosmos-minio
docker volume create cosmos-minio-v || exit /b
docker run --network cosmos -p 127.0.0.1:9000:9000 -d --name cosmos-minio -v cosmos-minio-v:/data minio/minio:RELEASE.2020-08-25T00-21-20Z server /data || exit /b
timeout 30 >nul

docker container rm cosmos-cmd-tlm-api
docker build -f cosmos-cmd-tlm-api\Dockerfile -t cosmos-cmd-tlm-api cosmos-cmd-tlm-api || exit /b
docker run --network cosmos -p 127.0.0.1:2901:2901 -d --name cosmos-cmd-tlm-api cosmos-cmd-tlm-api || exit /b

docker container rm cosmos-script-runner-api
docker build -f cosmos-script-runner-api\Dockerfile -t cosmos-script-runner-api cosmos-script-runner-api || exit /b
docker run --network cosmos -p 127.0.0.1:2902:2902 -d --name cosmos-script-runner-api cosmos-script-runner-api || exit /b

docker container rm cosmos-operator
docker build -f cosmos-operator\Dockerfile -t cosmos-operator cosmos-operator || exit /b
docker run --network cosmos -d --name cosmos-operator cosmos-operator || exit /b

docker container rm cosmos-traefik
docker build -f traefik\Dockerfile -t cosmos-traefik traefik || exit /b
docker run --network cosmos -p 127.0.0.1:2900:80 -d --name cosmos-traefik cosmos-traefik || exit /b

docker build -f cosmos-frontend-init\Dockerfile -t cosmos-frontend-init cosmos-frontend-init || exit /b
docker run --network cosmos --name cosmos-frontend-init --rm cosmos-frontend-init || exit /b

docker build -f cosmos-init\Dockerfile -t cosmos-init cosmos-init || exit /b
docker run --network cosmos --name cosmos-init --rm cosmos-init || exit /b

REM If everything is working you should be able to access Cosmos at http://localhost:2900/
