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

docker build -f cosmos/Dockerfile -t cosmos-base cosmos
docker push cosmos-base
docker tag cosmos-base localhost:5000/cosmos-base:latest

docker build -f geminabox/Dockerfile -t cosmos-gems geminabox
docker tag cosmos-gems localhost:5000/cosmos-gems:latest

docker build -f cmd_tlm_api/Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest

docker build -f script_runner_api/Dockerfile -t cosmos-script-runner-api script_runner_api
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest

docker build -f frontend/Dockerfile -t cosmos-frontend frontend
docker tag cosmos-frontend localhost:5000/cosmos-frontend:latest

docker build -f aggregator/Dockerfile -t cosmos-aggregator aggregator
docker tag cosmos-aggregator localhost:5000/cosmos-aggregator:latest

docker build -f operator/Dockerfile -t cosmos-operator operator
docker tag cosmos-operator localhost:5000/cosmos-operator:latest

docker build -f init/Dockerfile -t cosmos-init init
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
