#!/usr/bin/env bash

# exit when any command fails
set -e

docker build -f cosmos-ruby/Dockerfile -t cosmos-ruby cosmos-ruby
docker build -f cosmos-node/Dockerfile -t cosmos-node cosmos-node
docker build -f cosmos/Dockerfile -t cosmos-base cosmos
docker build -f cosmos-cmd-tlm-api/Dockerfile -t cosmos-cmd-tlm-api cosmos-cmd-tlm-api
docker build -f cosmos-script-runner-api/Dockerfile -t cosmos-script-runner-api cosmos-script-runner-api
docker build -f cosmos-frontend-init/Dockerfile -t cosmos-frontend-init cosmos-frontend-init
docker build -f cosmos-traefik/Dockerfile -t cosmos-traefik cosmos-traefik
docker build -f cosmos-operator/Dockerfile -t cosmos-operator cosmos-operator
docker build -f cosmos-init/Dockerfile -t cosmos-init cosmos-init
