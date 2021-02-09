#!/usr/bin/env bash
# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
touch cacert.pem

# You may need to comment out the below three lines if you are on linux host (as opposed to mac)
# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker build -f Dockerfile.cosmos_base -t cosmos-base .
docker push cosmos-base
docker tag cosmos-base localhost:5000/cosmos-base:latest

cd web/geminabox && docker build -t cosmos-gems .
docker tag cosmos-gems localhost:5000/cosmos-gems:latest

cd ../..
rm web/cmd_tlm_api/Gemfile.lock
docker build -f Dockerfile.cmd_tlm_api -t cosmos-cmd-tlm-api .
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest

rm web/script_runner_api/Gemfile.lock
docker build -f Dockerfile.script_runner_api -t cosmos-script-runner-api .
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest

docker build -f Dockerfile.frontend -t cosmos-frontend .
docker tag cosmos-frontend localhost:5000/cosmos-frontend:latest

docker build -f aggregator/dockerfile -t cosmos-aggregator aggregator
docker tag cosmos-aggregator localhost:5000/cosmos-aggregator:latest

docker build -f Dockerfile.operator -t cosmos-operator .
docker tag cosmos-operator localhost:5000/cosmos-operator:latest

docker build -f Dockerfile.init -t cosmos-init .
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
