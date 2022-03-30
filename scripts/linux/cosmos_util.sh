#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [encode, hash, svae, load]" >&2
  echo "*  encode: encode a string to base64" >&2
  echo "*  hash: hash a string using SHA-256" >&2
  echo "*  save: save images to a tar file" >&2
  echo "*  load: load images from a tar file" >&2
  echo "*  clean: remove node_modules, coverage, etc" >&2
  exit 1
}

saveTar() {
  mkdir -p tmp
  docker save minio/minio -o tmp/minio_minio.tar
  docker save ballaerospace/cosmosc2-minio-init -o tmp/cosmosc2-minio-init.tar
  docker save ballaerospace/cosmosc2-redis -o tmp/cosmosc2-redis.tar
  docker save ballaerospace/cosmosc2-traefik -o tmp/cosmosc2-traefik.tar
  docker save ballaerospace/cosmosc2-ruby -o tmp/cosmosc2-ruby.tar
  docker save ballaerospace/cosmosc2-node -o tmp/cosmosc2-node.tar
  docker save ballaerospace/cosmosc2-base -o tmp/cosmosc2-base.tar
  docker save ballaerospace/cosmosc2-cmd-tlm-api -o tmp/cosmosc2-cmd-tlm-api.tar
  docker save ballaerospace/cosmosc2-script-runner-api -o tmp/cosmosc2-script-runner-api.tar
  docker save ballaerospace/cosmosc2-operator -o tmp/cosmosc2-operator.tar
  docker save ballaerospace/cosmosc2-init  -o tmp/cosmosc2-init.tar
}

loadTar() {
  docker load -i tmp/minio_minio.tar
  docker load -i tmp/cosmosc2-minio-init.tar
  docker load -i tmp/cosmosc2-redis.tar
  docker load -i tmp/cosmosc2-traefik.tar
  docker load -i tmp/cosmosc2-ruby.tar
  docker load -i tmp/cosmosc2-node.tar
  docker load -i tmp/cosmosc2-base.tar
  docker load -i tmp/cosmosc2-cmd-tlm-api.tar
  docker load -i tmp/cosmosc2-script-runner-api.tar
  docker load -i tmp/cosmosc2-operator.tar
  docker load -i tmp/cosmosc2-init.tar
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
    saveTar
    ;;
  load )
    loadTar
    ;;
  clean )
    cleanFiles
    ;;
  * )
    usage $0
    ;;
esac
