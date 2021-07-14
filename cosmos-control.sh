#!/usr/bin/env sh

usage() {
  echo "Usage: $1 [cosmos, start, stop, cleanup, build, deploy]" >&2
  echo "*  cosmos: run a cosmos command ('cosmos help' for more info)" 1>&2
  echo "*  start: start the docker-compose cosmos" >&2
  echo "*  stop: stop the running dockers for cosmos" >&2
  echo "*  restart: stop and start the minimal docker run for cosmos" >&2
  echo "*  cleanup: cleanup network and volumes for cosmos" >&2
  echo "*  build: build the containers for cosmos" >&2
  echo "*  run: run the prebuilt containers for cosmos" >&2
  echo "*  dev: run cosmos in a dev mode" >&2
  echo "*  dind: build and run the docker development container (cosmos-build)" >&2
  echo "*  deploy: deploy the containers to localhost repository" >&2
  echo "*    repository: hostname of the docker repository" >&2
  echo "*  util: various helper commands" >&2
  echo "*    encode: encode a string to base64" >&2
  echo "*    hash: hash a string using SHA-256" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  usage $0
fi

if [ "$1" == "cosmos" ]; then
  # Start (and remove when done --rm) the cosmos-base container with the current working directory
  # mapped as volume (-v) /cosmos/local and container working directory (-w) also set to /cosmos/local.
  # This allows tools running in the container to have a consistent path to the current working directory.
  # Run the command "ruby /cosmos/bin/cosmos" with all parameters starting at 2 since the first is 'cosmos'
  args=`echo $@ | { read _ args; echo $args; }`
  docker run --rm -v `pwd`:/cosmos/local -w /cosmos/local ballaerospace/cosmosc2-base ruby /cosmos/bin/cosmos $args
elif [ "$1" == "start" ]; then
  scripts/linux/cosmos_setup.sh
  docker-compose -f compose.yaml -f compose-build.yaml build
  docker-compose -f compose.yaml up -d
elif [ "$1" == "stop" ]; then
  docker-compose -f compose.yaml down
elif [ "$1" == "restart" ]; then
  docker-compose -f compose.yaml restart
elif [ "$1" == "cleanup" ]; then
  docker-compose -f compose.yaml down -v
elif [ "$1" == "build" ]; then
  scripts/linux/cosmos_setup.sh
  docker-compose -f compose.yaml -f compose-build.yaml build
elif [ "$1" == "run" ]; then
  docker-compose -f compose.yaml up -d
elif [ "$1" == "dev" ]; then
  docker-compose -f compose.yaml -f compose-dev.yaml up -d
elif [ "$1" == "dind" ]; then
  docker build -t cosmos-build .
  docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock cosmos-build
elif [ "$1" == "deploy" ]; then
  scripts/linux/cosmos_deploy.sh $2
elif [ "$1" == "util" ]; then
  scripts/linux/cosmos_util.sh $2 $3
else
  usage $0
fi
