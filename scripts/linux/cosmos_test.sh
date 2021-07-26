#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [rspec, cypress]" >&2
  echo "*  rspec: run tests against Ruby code" >&2
  echo "*  cypress: run end-to-end tests" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  usage $0
fi

case $1 in
  rspec )
    cd cosmos
    rspec
    cd -
    ;;
  hash )
    docker-compose -f compose.yaml up -d
    cd cypress
    yarn
    yarn run fixlinux
    yarn run cypress run
    cd -
    docker-compose -f compose.yaml down -v
    ;;
  * )
    usage $0
    ;;
esac
