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
docker build -f Dockerfile.cosmos_base -t cosmos_base .
cd web/geminabox && docker build -t cosmos_gems .
cd ../..
docker volume create cosmos_gems_v
docker run --network cosmos -p 127.0.0.1:9292:9292 -d --name cosmos_gems -v cosmos_gems_v:/data cosmos_gems
cd web/fluentd && docker build -t cosmos_fluentd .
cd ../..
docker volume create cosmos_elasticsearch_v
docker run --network cosmos -p 127.0.0.1:9200:9200  -d --name cosmos_elasticsearch -v cosmos_elasticsearch_v:/usr/share/elasticsearch/data -e "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 --env discovery.type="single-node" --env ES_JAVA_OPTS="-Xms1g -Xmx1g" --env MALLOC_ARENA_MAX=4 elasticsearch:7.9.0
sleep 30
docker run --network cosmos -p 127.0.0.1:5601:5601  -d --name cosmos_kibana --env ELASTICSEARCH_HOSTS=http://cosmos_elasticsearch:9200 kibana:7.9.0
docker run --network cosmos -p 127.0.0.1:24224:24224 -p 127.0.0.1:24224:24224/udp -d --name cosmos_fluentd cosmos_fluentd
sleep 30
docker volume create cosmos_redis_v
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --name cosmos_redis -v cosmos_redis_v:/data --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=redis.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true redis:6.0.6 redis-server --appendonly yes
docker volume create cosmos_minio_v
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --name cosmos_minio -v cosmos_minio_v:/data --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=minio.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true minio/minio:RELEASE.2020-08-25T00-21-20Z server /data
sleep 30
rm web/cmd_tlm_api/Gemfile.lock
docker build -f Dockerfile.cmd_tlm_api -t cosmos_cmd_tlm_api .
rm web/script_runner_api/Gemfile.lock
docker build -f Dockerfile.script_runner_api -t cosmos_script_runner_api .
docker build -f Dockerfile.frontend -t cosmos_frontend .
docker build -f Dockerfile.operator -t cosmos_operator .
docker run --network cosmos -p 127.0.0.1:7777:7777 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=cmd_tlm_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_cmd_tlm_api cosmos_cmd_tlm_api
docker run --network cosmos -p 127.0.0.1:3001:3001 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=script_runner_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_script_runner_api cosmos_script_runner_api
docker run --network cosmos -p 127.0.0.1:8080:80 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=frontend.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_frontend cosmos_frontend
docker run --network cosmos -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=operator.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_operator cosmos_operator
docker build -f Dockerfile.init -t cosmos_init .
docker run --network cosmos --rm cosmos_init