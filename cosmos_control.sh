#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 [start, stop, build, cleanup, deploy, setup]" >&2
  exit 1
fi

case $1 in
start)
  scripts/linux/cosmos_minimal_start.sh
  ;;
stop)
  scripts/linux/cosmos_stop.sh
  ;;
build)
  scripts/linux/cosmos_build.sh
  ;;
cleanup)
  scripts/linux/cosmos_cleanup.sh
  ;;
deploy)
  scripts/linux/cosmos_deploy.sh
  ;;
setup)
  scripts/linux/cosmos_setup.sh
  ;;
*)
  echo "Usage: $0 [start, stop, build, cleanup, deploy, setup]" >&2
  exit 1
  ;;
esac
