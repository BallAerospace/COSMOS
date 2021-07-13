#!/usr/bin/env sh

# exit when any command fails
set -e

usage() {
  echo "Usage: $1 [repository]" >&2
  echo "*  repository: hostname of the docker repository" >&2
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  usage $0
fi

# Tag and push all the images to the local repository
docker tag ballaerospace/cosmosc2-ruby ${1}/cosmosc2-ruby:latest
docker tag ballaerospace/cosmosc2-node ${1}/cosmosc2-node:latest
docker tag ballaerospace/cosmosc2-base ${1}/cosmosc2-base:latest
docker tag ballaerospace/cosmosc2-cmd-tlm-api ${1}/cosmosc2-cmd-tlm-api:latest
docker tag ballaerospace/cosmosc2-script-runner-api ${1}/cosmosc2-script-runner-api:latest
docker tag ballaerospace/cosmosc2-frontend-init ${1}/cosmosc2-frontend-init:latest
docker tag ballaerospace/cosmosc2-operator ${1}/cosmosc2-operator:latest
docker tag ballaerospace/cosmosc2-init ${1}/cosmosc2-init:latest
docker tag ballaerospace/cosmosc2-redis ${1}/cosmosc2-redis:latest

docker push ${1}/cosmosc2-ruby:latest
docker push ${1}/cosmosc2-node:latest
docker push ${1}/cosmosc2-base:latest
docker push ${1}/cosmosc2-cmd-tlm-api:latest
docker push ${1}/cosmosc2-script-runner-api:latest
docker push ${1}/cosmosc2-frontend-init:latest
docker push ${1}/cosmosc2-operator:latest
docker push ${1}/cosmosc2-init:latest
docker push ${1}/cosmosc2-redis:latest
