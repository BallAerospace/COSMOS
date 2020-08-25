docker network create cosmos
docker build -f Dockerfile.cosmos_base -t cosmos_base .
cd web\fluentd && docker build -t cosmos_fluentd .
cd ..\..
docker run --network cosmos -p 127.0.0.1:9200:9200  -d --name cosmos_elasticsearch --env discovery.type="single-node" --env ES_JAVA_OPTS="-Xms750m -Xmx750m" elasticsearch:7.6.2
timeout 30 >nul
docker run --network cosmos -p 127.0.0.1:5601:5601  -d --name cosmos_kibana --env ELASTICSEARCH_HOSTS=http://cosmos_elasticsearch:9200 kibana:7.6.2
docker run --network cosmos -p 127.0.0.1:24224:24224 -p 127.0.0.1:24224:24224/udp -d --name cosmos_fluentd cosmos_fluentd
timeout 30 >nul
docker run --network cosmos -p 127.0.0.1:6379:6379  -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=redis.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_redis redis:latest
docker run --network cosmos -p 127.0.0.1:9000:9000  -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=minio.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_minio minio/minio:latest server /data
timeout 30 >nul
del web\cmd_tlm_api\Gemfile.lock
docker build -f Dockerfile.cmd_tlm_api -t cosmos_cmd_tlm_api .
del web\script_runner_api\Gemfile.lock
docker build -f Dockerfile.script_runner_api -t cosmos_script_runner_api .
docker build -f Dockerfile.frontend -t cosmos_frontend .
docker build -f Dockerfile.operator -t cosmos_operator .
docker run --network cosmos -p 127.0.0.1:7777:7777 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=cmd_tlm_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_cmd_tlm_api cosmos_cmd_tlm_api
docker run --network cosmos -p 127.0.0.1:3001:3001 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=script_runner_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_script_runner_api cosmos_script_runner_api
docker run --network cosmos -p 127.0.0.1:8080:80 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=frontend.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_frontend cosmos_frontend
docker run --network cosmos --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=cmd_tlm_api.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos_operator cosmos_operator