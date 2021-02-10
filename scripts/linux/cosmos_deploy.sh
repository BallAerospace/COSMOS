#!/usr/bin/env bash
# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
touch cacert.pem

docker tag cosmos-base localhost:5000/cosmos-base:latest

docker tag cosmos-gems localhost:5000/cosmos-gems:latest

docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest

docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest

docker tag cosmos-frontend localhost:5000/cosmos-frontend:latest

docker tag cosmos-aggregator localhost:5000/cosmos-aggregator:latest

docker tag cosmos-operator localhost:5000/cosmos-operator:latest

docker tag cosmos-init localhost:5000/cosmos-init:latest

# Push all the images to the local repository
docker push localhost:5000/cosmos-base:latest

docker push localhost:5000/cosmos-gems:latest

docker push localhost:5000/cosmos-cmd-tlm-api:latest

docker push localhost:5000/cosmos-script-runner-api:latest

docker push localhost:5000/cosmos-frontend:latest

docker push localhost:5000/cosmos-aggregator:latest

docker push localhost:5000/cosmos-operator:latest

docker push localhost:5000/cosmos-init:latest
