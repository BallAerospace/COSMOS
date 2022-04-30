#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [rspec, playwright]" >&2
  echo "*  rspec: run tests against Ruby code" >&2
  echo "*  playwright: run end-to-end tests" >&2
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
    cd playwright
    yarn run fixlinux
    yarn playwright test
    yarn coverage
    cd -
    ;;
  * )
    usage $0
    ;;
esac
