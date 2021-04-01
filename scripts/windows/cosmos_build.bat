@echo off

REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b

docker build -f cosmos\Dockerfile -t cosmos-base cosmos || exit /b
docker build -f geminabox\Dockerfile -t cosmos-gems geminabox || exit /b
docker build -f cmd_tlm_api\Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api || exit /b
docker build -f script_runner_api\Dockerfile -t cosmos-script-runner-api script_runner_api || exit /b
docker build -f frontend\Dockerfile -t cosmos-frontend-init frontend || exit /b
docker build -f operator\Dockerfile -t cosmos-operator operator || exit /b
docker build -f init\Dockerfile -t cosmos-init init || exit /b

if "%1" == "dev" (
  docker build -f elasticsearch/Dockerfile -t cosmos-elasticsearch elasticsearch || exit /b
  docker build -f kibana/Dockerfile -t cosmos-kibana kibana || exit /b
  docker build -f fluentd/Dockerfile -t cosmos-fluentd fluentd || exit /b
  docker build -f grafana/Dockerfile -t cosmos-grafana grafana || exit /b
  docker build -f prometheus/Dockerfile -t cosmos-prometheus prometheus || exit /b
)
