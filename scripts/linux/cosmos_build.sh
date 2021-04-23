#!/usr/bin/env bash

# exit when any command fails
set -e

# You may need to comment out the below three lines if you are on linux host (as opposed to mac)
# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker build -f cosmos-ruby/Dockerfile -t cosmos-ruby cosmos-ruby
docker build -f cosmos-node/Dockerfile -t cosmos-node cosmos-node
docker build -f cosmos/Dockerfile -t cosmos-base cosmos
docker build -f cosmos-cmd-tlm-api/Dockerfile -t cosmos-cmd-tlm-api cosmos-cmd-tlm-api
docker build -f cosmos-script-runner-api/Dockerfile -t cosmos-script-runner-api cosmos-script-runner-api
docker build -f cosmos-frontend/Dockerfile -t cosmos-frontend-init cosmos-frontend
docker build -f cosmos-operator/Dockerfile -t cosmos-operator cosmos-operator
docker build -f cosmos-init/Dockerfile -t cosmos-init cosmos-init

if [[ "$1" == "dev" ]]; then
  docker build -f elasticsearch/Dockerfile -t cosmos-elasticsearch elasticsearch
  docker build -f kibanan/Dockerfile -t cosmos-kibana kibana
  docker build -f fluentd/Dockerfile -t cosmos-fluentd fluentd
  docker build -f grafana/Dockerfile -t cosmos-grafana grafana
  docker build -f prometheus/Dockerfile -t cosmos-prometheus prometheus
fi
