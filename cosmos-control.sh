#!/usr/bin/env bash

usage() {
  echo "Usage: $1 [start, stop, cleanup, build, deploy]" >&2
  echo "*  start: start the minimal docker run for cosmos" >&2
  echo "*  stop: stop the running dockers for cosmos" >&2
  echo "*  restart: stop and start the minimal docker run for cosmos" >&2
  echo "*  cleanup: cleanup network and volumes for cosmos" >&2
  echo "*  build: build the containers for cosmos" >&2
  echo "*  run: run the prebuilt containers for cosmos" >&2
  echo "*  deploy: deploy the containers to localhost repository" >&2
  exit 1
}

if [[ "$#" -eq 0 ]]; then
  usage $0
fi

case $1 in
start)
  scripts/linux/cosmos_setup.sh
  scripts/linux/cosmos_build.sh
  scripts/linux/cosmos_run.sh
  ;;
stop)
  scripts/linux/cosmos_stop.sh
  ;;
restart)
  scripts/linux/cosmos_restart.sh
  ;;
cleanup)
  scripts/linux/cosmos_cleanup.sh
  ;;
build)
  scripts/linux/cosmos_setup.sh
  scripts/linux/cosmos_build.sh
  ;;
run)
  scripts/linux/cosmos_run.sh
  ;;
deploy)
  scripts/linux/cosmos_deploy.sh
  ;;
*)
  usage $0
  ;;
esac
