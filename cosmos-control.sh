#!/usr/bin/env bash

usage() {
  echo "Usage: $1 [setup, start, stop, cleanup, build, deploy]" >&2
  echo "  All commands take a 'dev' option to start additional containers" >&2
  echo "*  setup: setup containers to build and run" >&2
  echo "*  start: start the minimal docker run for cosmos" >&2
  echo "*  stop: stop the running dockers for cosmos" >&2
  echo "*  cleanup: cleanup network and volumes for cosmos" >&2
  echo "*  build: build the containers for cosmos" >&2
  echo "*  deploy: deploy the containers to localhost repository" >&2
  exit 1
}

if [[ "$#" -eq 0 ]]; then
  usage $0
fi

case $1 in
setup)
  scripts/linux/cosmos_setup.sh
  ;;
start)
  scripts/linux/cosmos_setup.sh
  scripts/linux/cosmos_start.sh $2
  ;;
stop)
  scripts/linux/cosmos_stop.sh $2
  ;;
cleanup)
  scripts/linux/cosmos_cleanup.sh $2
  ;;
build)
  scripts/linux/cosmos_setup.sh
  scripts/linux/cosmos_build.sh $2
  ;;
deploy)
  scripts/linux/cosmos_deploy.sh $2
  ;;
*)
  usage $0
  ;;
esac
