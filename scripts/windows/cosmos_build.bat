@echo off

REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b

docker build -f cosmos-ruby\Dockerfile -t cosmos-ruby cosmos-ruby || exit /b
docker build -f cosmos-node\Dockerfile -t cosmos-node cosmos-node || exit /b
docker build -f cosmos\Dockerfile -t cosmos-base cosmos || exit /b
docker build -f cosmos-gems\Dockerfile -t cosmos-gems cosmos-gems || exit /b
docker build -f cosmos-cmd-tlm-api\Dockerfile -t cosmos-cmd-tlm-api cosmos-cmd-tlm-api || exit /b
docker build -f cosmos-script-runner-api\Dockerfile -t cosmos-script-runner-api cosmos-script-runner-api || exit /b
docker build -f cosmos-frontend-init\Dockerfile -t cosmos-frontend-init cosmos-frontend-init || exit /b
docker build -f cosmos-operator\Dockerfile -t cosmos-operator cosmos-operator || exit /b
docker build -f cosmos-init\Dockerfile -t cosmos-init cosmos-init || exit /b

if "%1" == "dev" (
  docker build -f elasticsearch/Dockerfile -t cosmos-elasticsearch elasticsearch || exit /b
  docker build -f kibana/Dockerfile -t cosmos-kibana kibana || exit /b
  docker build -f fluentd/Dockerfile -t cosmos-fluentd fluentd || exit /b
  docker build -f grafana/Dockerfile -t cosmos-grafana grafana || exit /b
  docker build -f prometheus/Dockerfile -t cosmos-prometheus prometheus || exit /b
)
