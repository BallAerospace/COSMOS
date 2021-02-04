
REM docker build -f Dockerfile.cosmos_base -t cosmos-base .

docker container rm cosmos-aggregator
docker build -f aggregator/dockerfile -t cosmos-aggregator aggregator
docker run --network cosmos -p 127.0.0.1:3113:3113 -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=aggregator.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true --name cosmos-aggregator cosmos-aggregator

REM docker container rm cosmos-operator
REM docker build -f Dockerfile.operator -t cosmos-operator .
REM docker run --network cosmos -d --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=operator.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true -p 7779:7779 --name cosmos-operator cosmos-operator

REM --log-driver=fluentd --log-opt fluentd-address=127.0.0.1:24224 --log-opt tag=redis.log --log-opt fluentd-async-connect=true --log-opt fluentd-sub-second-precision=true

REM curl -X POST http://localhost:5601/api/saved_objects/_import?createNewCopies=true -H "kbn-xsrf:true" --form file=@kibana\export.ndjson -w "\n"
