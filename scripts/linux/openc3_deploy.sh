#!/usr/bin/env sh

# exit when any command fails
set -e

usage() {
  echo "Usage: $1 [repository]" >&2
  echo "*  repository: hostname of the docker repository" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage $0
fi

# Tag and push all the images to the local repository
docker tag openc3/openc3-ruby ${1}/openc3-ruby:latest
docker tag openc3/openc3-node ${1}/openc3-node:latest
docker tag openc3/openc3-base ${1}/openc3-base:latest
docker tag openc3/openc3-cmd-tlm-api ${1}/openc3-cmd-tlm-api:latest
docker tag openc3/openc3-script-runner-api ${1}/openc3-script-runner-api:latest
docker tag openc3/openc3-operator ${1}/openc3-operator:latest
docker tag openc3/openc3-init ${1}/openc3-init:latest
docker tag openc3/openc3-redis ${1}/openc3-redis:latest
docker tag openc3/openc3-minio ${1}/openc3-minio:latest

docker push ${1}/openc3-ruby:latest
docker push ${1}/openc3-node:latest
docker push ${1}/openc3-base:latest
docker push ${1}/openc3-cmd-tlm-api:latest
docker push ${1}/openc3-script-runner-api:latest
docker push ${1}/openc3-operator:latest
docker push ${1}/openc3-init:latest
docker push ${1}/openc3-redis:latest
docker push ${1}/openc3-minio:latest