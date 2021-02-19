#!/usr/bin/env bash
# Please see cosmos_setup.sh

docker build -f cosmos/Dockerfile -t cosmos-base cosmos

docker build -f geminabox/Dockerfile -t cosmos-gems geminabox

docker build -f cmd_tlm_api/Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api

docker build -f script_runner_api/Dockerfile -t cosmos-script-runner-api script_runner_api

docker build -f frontend/Dockerfile -t cosmos-frontend frontend

docker build -f operator/Dockerfile -t cosmos-operator operator

docker build -f init/Dockerfile -t cosmos-init init

docker build -f aggregator/Dockerfile -t cosmos-aggregator aggregator

docker build -f elasticsearch/Dockerfile -t cosmos-elasticsearch elasticsearch

docker build -f kibanan/Dockerfile -t cosmos-kibana kibana

docker build -f fluentd/Dockerfile -t cosmos-fluentd fluentd

docker build -f grafana/Dockerfile -t cosmos-grafana grafana

docker build -f prometheus/Dockerfile -t cosmos-prometheus prometheus
