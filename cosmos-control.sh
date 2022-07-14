#!/usr/bin/env sh

set -e

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
  echo "*  test: test COSMOS" >&2
  echo "*    rspec: run tests against Ruby code" >&2
  echo "*    playwright: run end-to-end tests" >&2
  echo "*  util: various helper commands" >&2
  echo "*    encode: encode a string to base64" >&2
  echo "*    hash: hash a string using SHA-256" >&2
  echo "*    save: save images to tar files" >&2
  echo "*    load: load images to tar files" >&2
  echo "*    clean: remove node_modules, coverage, etc" >&2
  echo "*    hostsetup: setup host for redis" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  usage $0
fi

case $1 in
  cosmos )
    # Source the .env file to setup environment variables
    set -a
    . "$(dirname -- "$0")/.env"
    # Start (and remove when done --rm) the cosmos-base container with the current working directory
    # mapped as volume (-v) /cosmos/local and container working directory (-w) also set to /cosmos/local.
    # This allows tools running in the container to have a consistent path to the current working directory.
    # Run the command "ruby /cosmos/bin/cosmos" with all parameters starting at 2 since the first is 'cosmos'
    args=`echo $@ | { read _ args; echo $args; }`
    docker run --rm -v `pwd`:/cosmos/local -w /cosmos/local ballaerospace/cosmosc2-base:$COSMOS_TAG ruby /cosmos/bin/cosmos $args
    set +a
    ;;
  start )
    ./cosmos-control.sh build
    docker-compose -f compose.yaml -f compose-build.yaml build
    docker-compose -f compose.yaml up -d
    ;;
  stop )
    docker-compose -f compose.yaml down
    ;;
  restart )
    docker-compose -f compose.yaml restart
    ;;
  cleanup )
    docker-compose -f compose.yaml down -v
    ;;
  build )
    scripts/linux/cosmos_setup.sh
    docker-compose -f compose.yaml -f compose-build.yaml build cosmos-ruby
    docker-compose -f compose.yaml -f compose-build.yaml build cosmos-base
    docker-compose -f compose.yaml -f compose-build.yaml build cosmos-node
    docker-compose -f compose.yaml -f compose-build.yaml build
    ;;
  run )
    docker-compose -f compose.yaml up -d
    ;;
  dev )
    docker-compose -f compose.yaml -f compose-dev.yaml up -d
    ;;
  dind )
    docker build -t cosmos-build .
    docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock cosmos-build
    ;;
  deploy )
    scripts/linux/cosmos_deploy.sh $2
    ;;
  test )
    scripts/linux/cosmos_setup.sh
    docker-compose -f compose.yaml -f compose-build.yaml build
    scripts/linux/cosmos_test.sh $2
    ;;
  util )
    scripts/linux/cosmos_util.sh $2 $3
    ;;
  * )
    usage $0
    ;;
esac
