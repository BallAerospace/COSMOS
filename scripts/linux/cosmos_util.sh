#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [encode, hash, save, load, clean, hostsetup]" >&2
  echo "*  encode: encode a string to base64" >&2
  echo "*  hash: hash a string using SHA-256" >&2
  echo "*  save: save images to a tar file" >&2
  echo "*  load: load images from a tar file" >&2
  echo "*  clean: remove node_modules, coverage, etc" >&2
  echo "*  hostsetup: configure host for redis" >&2
  exit 1
}

saveTar() {
  mkdir -p tmp
  if [ -z "$1" ]; then
    tag='latest'
  else
    tag=$1
    docker pull ballaerospace/cosmosc2-ruby:$tag
    docker pull ballaerospace/cosmosc2-base:$tag
    docker pull ballaerospace/cosmosc2-node:$tag
    docker pull ballaerospace/cosmosc2-operator:$tag
    docker pull ballaerospace/cosmosc2-cmd-tlm-api:$tag
    docker pull ballaerospace/cosmosc2-script-runner-api:$tag
    docker pull ballaerospace/cosmosc2-traefik:$tag
    docker pull ballaerospace/cosmosc2-redis:$tag
    docker pull ballaerospace/cosmosc2-minio:$tag
    docker pull ballaerospace/cosmosc2-init:$tag
  fi
  docker pull minio/minio:RELEASE.2021-06-17T00-10-46Z
  docker save minio/minio:RELEASE.2021-06-17T00-10-46Z -o tmp/minio-minio-2021-06-17T00-10-46Z.tar
  docker save ballaerospace/cosmosc2-ruby:$tag -o tmp/cosmosc2-ruby-$tag.tar
  docker save ballaerospace/cosmosc2-base:$tag -o tmp/cosmosc2-base-$tag.tar
  docker save ballaerospace/cosmosc2-node:$tag -o tmp/cosmosc2-node-$tag.tar
  docker save ballaerospace/cosmosc2-operator:$tag -o tmp/cosmosc2-operator-$tag.tar
  docker save ballaerospace/cosmosc2-cmd-tlm-api:$tag -o tmp/cosmosc2-cmd-tlm-api-$tag.tar
  docker save ballaerospace/cosmosc2-script-runner-api:$tag -o tmp/cosmosc2-script-runner-api-$tag.tar
  docker save ballaerospace/cosmosc2-traefik:$tag -o tmp/cosmosc2-traefik-$tag.tar
  docker save ballaerospace/cosmosc2-redis:$tag -o tmp/cosmosc2-redis-$tag.tar
  docker save ballaerospace/cosmosc2-minio:$tag -o tmp/cosmosc2-minio-$tag.tar
  docker save ballaerospace/cosmosc2-init:$tag -o tmp/cosmosc2-init-$tag.tar
}

loadTar() {
  if [ -z "$1" ]; then
    tag='latest'
  else
    tag=$1
  fi
  docker load -i tmp/minio-minio-2021-06-17T00-10-46Z.tar
  docker load -i tmp/cosmosc2-ruby-$tag.tar
  docker load -i tmp/cosmosc2-base-$tag.tar
  docker load -i tmp/cosmosc2-node-$tag.tar
  docker load -i tmp/cosmosc2-operator-$tag.tar
  docker load -i tmp/cosmosc2-cmd-tlm-api-$tag.tar
  docker load -i tmp/cosmosc2-script-runner-api-$tag.tar
  docker load -i tmp/cosmosc2-traefik-$tag.tar
  docker load -i tmp/cosmosc2-redis-$tag.tar
  docker load -i tmp/cosmosc2-minio-$tag.tar
  docker load -i tmp/cosmosc2-init-$tag.tar
}

cleanFiles() {
  find . -type d -name "node_modules" | xargs -I {} echo "Removing {}"; rm -rf {}
  find . -type d -name "coverage" | xargs -I {} echo "Removing {}"; rm -rf {}
  # Prompt for removing yarn.lock files
  find . -type f -name "yarn.lock" | xargs -I {} rm -i {}
  # Prompt for removing Gemfile.lock files
  find . -type f -name "Gemfile.lock" | xargs -I {} rm -i {}
}

if [ "$#" -eq 0 ]; then
  usage $0
fi

case $1 in
  encode )
    echo -n $2 | base64
    ;;
  hash )
    echo -n $2 | shasum -a 256 | sed 's/-//'
    ;;
  save )
    saveTar $2
    ;;
  load )
    loadTar $2
    ;;
  clean )
    cleanFiles
    ;;
  hostsetup )
    docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
    docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
    docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"
    ;;
  * )
    usage $0
    ;;
esac
