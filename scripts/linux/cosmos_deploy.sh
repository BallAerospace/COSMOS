#!/usr/bin/env bash

# exit when any command fails
set -e

# Tag and push all the images to the local repository
docker tag cosmos-ruby localhost:5000/cosmos-ruby:latest
docker tag cosmos-node localhost:5000/cosmos-node:latest
docker tag cosmos-base localhost:5000/cosmos-base:latest
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest
docker tag cosmos-frontend-init localhost:5000/cosmos-frontend-init:latest
docker tag cosmos-operator localhost:5000/cosmos-operator:latest
docker tag cosmos-init localhost:5000/cosmos-init:latest

docker push localhost:5000/cosmos-ruby:latest
docker push localhost:5000/cosmos-node:latest
docker push localhost:5000/cosmos-base:latest
docker push localhost:5000/cosmos-cmd-tlm-api:latest
docker push localhost:5000/cosmos-script-runner-api:latest
docker push localhost:5000/cosmos-frontend-init:latest
docker push localhost:5000/cosmos-operator:latest
docker push localhost:5000/cosmos-init:latest
