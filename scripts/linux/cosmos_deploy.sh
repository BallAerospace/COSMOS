#!/usr/bin/env bash

# exit when any command fails
set -e

# Tag and push all the images to the local repository
docker tag ballaerospace/cosmosc2-ruby localhost:5000/cosmosc2-ruby:latest
docker tag ballaerospace/cosmosc2-node localhost:5000/cosmosc2-node:latest
docker tag ballaerospace/cosmosc2-base localhost:5000/cosmosc2-base:latest
docker tag ballaerospace/cosmosc2-cmd-tlm-api localhost:5000/cosmosc2-cmd-tlm-api:latest
docker tag ballaerospace/cosmosc2-script-runner-api localhost:5000/cosmosc2-script-runner-api:latest
docker tag ballaerospace/cosmosc2-frontend-init localhost:5000/cosmosc2-frontend-init:latest
docker tag ballaerospace/cosmosc2-operator localhost:5000/cosmosc2-operator:latest
docker tag ballaerospace/cosmosc2-init localhost:5000/cosmosc2-init:latest

docker push localhost:5000/cosmosc2-ruby:latest
docker push localhost:5000/cosmosc2-node:latest
docker push localhost:5000/cosmosc2-base:latest
docker push localhost:5000/cosmosc2-cmd-tlm-api:latest
docker push localhost:5000/cosmosc2-script-runner-api:latest
docker push localhost:5000/cosmosc2-frontend-init:latest
docker push localhost:5000/cosmosc2-operator:latest
docker push localhost:5000/cosmosc2-init:latest
