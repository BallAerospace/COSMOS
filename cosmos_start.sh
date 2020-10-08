#!/usr/bin/env bash
# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
# You may need to comment out the below three lines if you are on linux host (as opposed to mac)
touch cacert.pem
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"
docker network create cosmos
docker build -f Dockerfile.cosmos_base -t cosmos-base .
cd web/geminabox && docker build -t cosmos-gems .
cd ../..
docker volume create cosmos-gems-v
docker run --network cosmos -p 127.0.0.1:9292:9292 -d --name cosmos-gems -v cosmos-gems-v:/data cosmos-gems
cd web/fluentd && docker build -t cosmos-fluentd .
cd ../..
docker volume create cosmos-elasticsearch-v
docker run --network cosmos -p 127.0.0.1:9200:9200  -d --name cosmos-elasticsearch -v cosmos-elasticsearch-v:/usr/share/elasticsearch/data -e "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 --env discovery.type="single-node" --env ES_JAVA_OPTS="-Xms1g -Xmx1g" --env MALLOC_ARENA_MAX=4 elasticsearch:7.9.0
sleep 30
docker run --network cosmos -p 127.0.0.1:5601:5601  -d --name cosmos-kibana --env ELASTICSEARCH_HOSTS=http://cosmos-elasticsearch:9200 kibana:7.9.0
docker run --network cosmos -p 127.0.0.1:24224:24224 -p 127.0.0.1:24224:24224/udp -d --name cosmos-fluentd cosmos-fluentd
sleep 30
docker volume create cosmos-redis-v
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --name cosmos-redis -v cosmos-redis-v:/data --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=redis.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true redis:6.0.6 redis-server --appendonly yes
docker volume create cosmos-minio-v
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --name cosmos-minio -v cosmos-minio-v:/data --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=minio.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true minio/minio:RELEASE.2020-08-25T00-21-20Z server /data
sleep 30
rm web/cmd_tlm_api/Gemfile.lock
docker build -f Dockerfile.cmd_tlm_api -t cosmos-cmd-tlm-api .
rm web/script_runner_api/Gemfile.lock
docker build -f Dockerfile.script_runner_api -t cosmos-script-runner-api .
docker build -f Dockerfile.frontend -t cosmos-frontend .
docker build -f Dockerfile.operator -t cosmos-operator .
docker run --network cosmos -p 127.0.0.1:7777:7777 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=cmd_tlm_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos-cmd-tlm-api cosmos-cmd-tlm-api
docker run --network cosmos -p 127.0.0.1:3001:3001 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=script_runner_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos-script-runner-api cosmos-script-runner-api
docker run --network cosmos -p 127.0.0.1:8080:80 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=frontend.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos-frontend cosmos-frontend
docker run --network cosmos -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=operator.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos-operator cosmos-operator
docker build -f Dockerfile.init -t cosmos-init .
docker run --network cosmos --rm cosmos-init