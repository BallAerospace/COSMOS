#!/usr/bin/env bash

usage() {
  echo "Usage: $1 [cosmos, start, stop, cleanup, build, deploy]" >&2
  echo "*  cosmos: run a cosmos command ('cosmos help' for more info)" 1>&2
  echo "*  start: start the minimal docker run for cosmos" >&2
  echo "*  stop: stop the running dockers for cosmos" >&2
  echo "*  restart: stop and start the minimal docker run for cosmos" >&2
  echo "*  cleanup: cleanup network and volumes for cosmos" >&2
  echo "*  build: build the containers for cosmos" >&2
  echo "*  run: run the prebuilt containers for cosmos" >&2
  echo "*  deploy: deploy the containers to localhost repository" >&2
  echo "*    repository: hostname of the docker repository" >&2
  echo "*  util: various helper commands" >&2
  echo "*    encode: encode a string to base64" >&2
  echo "*    hash: hash a string using SHA-256" >&2
  exit 1
}

if [[ "$#" -eq 0 ]]; then
  usage $0
fi

case $1 in
cosmos)
  # Start (and remove when done --rm) the cosmos-base container with the current working directory
  # mapped as volume (-v) /cosmos/local and container working directory (-w) also set to /cosmos/local.
  # This allows tools running in the container to have a consistent path to the current working directory.
  # Run the command "ruby /cosmos/bin/cosmos" with all parameters starting at 2 since the first is 'cosmos'
  docker run --rm -v $(pwd):/cosmos/local -w /cosmos/local cosmos-base ruby /cosmos/bin/cosmos ${@:2}
  ;;
start)
  scripts/linux/cosmos_setup.sh
  docker-compose build
  docker-compuse up -d
  ;;
stop)
  docker-compose down
  ;;
restart)
  docker-compose restart
  ;;
cleanup)
  docker-compose down -v
  ;;
build)
  scripts/linux/cosmos_setup.sh
  docker-compose build
  ;;
run)
  docker-compuse up -d
  ;;
deploy)
  scripts/linux/cosmos_deploy.sh $2
  ;;
util)
  scripts/linux/cosmos_util.sh $2 $3
  ;;
*)
  usage $0
  ;;
esac
