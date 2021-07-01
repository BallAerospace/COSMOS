#!/usr/bin/env bash

# exit when any command fails
set -e

docker build -f cosmos-redis/Dockerfile -t ballaerospace/cosmosc2-redis cosmos-redis
docker build -f cosmos-ruby/Dockerfile -t ballaerospace/cosmosc2-ruby cosmos-ruby
docker build -f cosmos-node/Dockerfile -t ballaerospace/cosmosc2-node cosmos-node
docker build -f cosmos/Dockerfile -t ballaerospace/cosmosc2-base cosmos
docker build -f cosmos-cmd-tlm-api/Dockerfile -t ballaerospace/cosmosc2-cmd-tlm-api cosmos-cmd-tlm-api
docker build -f cosmos-script-runner-api/Dockerfile -t ballaerospace/cosmosc2-script-runner-api cosmos-script-runner-api
docker build -f cosmos-frontend-init/Dockerfile -t ballaerospace/cosmosc2-frontend-init cosmos-frontend-init
docker build -f cosmos-traefik/Dockerfile -t ballaerospace/cosmosc2-traefik cosmos-traefik
docker build -f cosmos-operator/Dockerfile -t ballaerospace/cosmosc2-operator cosmos-operator
docker build -f cosmos-init/Dockerfile -t ballaerospace/cosmosc2-init cosmos-init
