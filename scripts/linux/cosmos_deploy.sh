#!/usr/bin/env bash

# Tag and push all the images to the local repository
docker tag cosmos-base localhost:5000/cosmos-base:latest
docker tag cosmos-gems localhost:5000/cosmos-gems:latest
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest
docker tag cosmos-frontend localhost:5000/cosmos-frontend:latest
docker tag cosmos-aggregator localhost:5000/cosmos-aggregator:latest
docker tag cosmos-operator localhost:5000/cosmos-operator:latest
docker tag cosmos-init localhost:5000/cosmos-init:latest

docker push localhost:5000/cosmos-base:latest
docker push localhost:5000/cosmos-gems:latest
docker push localhost:5000/cosmos-cmd-tlm-api:latest
docker push localhost:5000/cosmos-script-runner-api:latest
docker push localhost:5000/cosmos-frontend:latest
docker push localhost:5000/cosmos-aggregator:latest
docker push localhost:5000/cosmos-operator:latest
docker push localhost:5000/cosmos-init:latest

if [[ "$1" == "dev" ]]; then
  docker tag cosmos-aggregator localhost:5000/cosmos-aggregator:latest
  docker tag cosmos-elasticsearch localhost:5000/cosmos-elasticsearch:latest
  docker tag cosmos-kibana localhost:5000/cosmos-kibana:latest
  docker tag cosmos-fluentd localhost:5000/cosmos-fluentd:latest
  docker tag cosmos-grafana localhost:5000/cosmos-grafana:latest
  docker tag cosmos-prometheus localhost:5000/cosmos-prometheus:latest

  docker push localhost:5000/cosmos-aggregator:latest
  docker push localhost:5000/cosmos-elasticsearch:latest
  docker push localhost:5000/cosmos-kibana:latest
  docker push localhost:5000/cosmos-fluentd:latest
  docker push localhost:5000/cosmos-grafana:latest
  docker push localhost:5000/cosmos-prometheus:latest
fi
