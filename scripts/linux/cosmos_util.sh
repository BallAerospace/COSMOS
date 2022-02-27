#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [encode, hash, svae, load]" >&2
  echo "*  encode: encode a string to base64" >&2
  echo "*  hash: hash a string using SHA-256" >&2
  echo "*  save: save images to a tar file" >&2
  echo "*  load: load images from a tar file" >&2
  exit 1
}

saveTar() {
  docker save minio/minio -o minio_minio.tar
  docker save ballaerospace/cosmosc2-minio-init -o cosmosc2-minio-init.tar
  docker save ballaerospace/cosmosc2-ruby -o cosmosc2-ruby.tar
  docker save ballaerospace/cosmosc2-node -o cosmosc2-node.tar
  docker save ballaerospace/cosmosc2-base -o cosmosc2-base.tar
  docker save ballaerospace/cosmosc2-cmd-tlm-api -o cosmosc2-cmd-tlm-api.tar
  docker save ballaerospace/cosmosc2-script-runner-api -o cosmosc2-script-runner-api.tar
  docker save ballaerospace/cosmosc2-operator -o cosmosc2-operator.tar
  docker save ballaerospace/cosmosc2-init  -o cosmosc2-init.tar
  docker save ballaerospace/cosmosc2-redis -o cosmosc2-redis.tar
  docker save ballaerospace/cosmosc2-traefik -o cosmosc2-traefik.tar
}

loadTar() {
  docker load -i minio_minio.tar
  docker load -i cosmosc2-minio-init.tar
  docker load -i cosmosc2-traefik.tar
  docker load -i cosmosc2-ruby.tar
  docker load -i cosmosc2-node.tar
  docker load -i cosmosc2-base.tar
  docker load -i cosmosc2-cmd-tlm-api.tar
  docker load -i cosmosc2-script-runner-api.tar
  docker load -i cosmosc2-operator.tar
  docker load -i cosmosc2-init.tar
  docker load -i cosmosc2-redis.tar
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
  * )
    usage $0
    ;;
esac
