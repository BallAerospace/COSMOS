#!/usr/bin/env sh

set -e

usage() {
  echo "Usage: $1 [openc3cli, start, stop, cleanup, build, deploy]" >&2
  echo "*  openc3: run a openc3cli command ('openc3cli help' for more info)" 1>&2
  echo "*  start: start the docker-compose openc3" >&2
  echo "*  stop: stop the running dockers for openc3" >&2
  echo "*  cleanup: cleanup network and volumes for openc3" >&2
  echo "*  build: build the containers for openc3" >&2
  echo "*  run: run the prebuilt containers for openc3" >&2
  echo "*  dev: run openc3 in a dev mode" >&2
  echo "*  deploy: deploy the containers to localhost repository" >&2
  echo "*    repository: hostname of the docker repository" >&2
  echo "*  test: test openc3" >&2
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
  openc3cli )
    # Source the .env file to setup environment variables
    set -a
    . "$(dirname -- "$0")/.env"
    # Start (and remove when done --rm) the openc3-base container with the current working directory
    # mapped as volume (-v) /openc3/local and container working directory (-w) also set to /openc3/local.
    # This allows tools running in the container to have a consistent path to the current working directory.
    # Run the command "ruby /openc3/bin/openc3cli" with all parameters starting at 2 since the first is 'openc3'
    args=`echo $@ | { read _ args; echo $args; }`
    docker run --rm -v `pwd`:/openc3/local -w /openc3/local openc3/openc3-base:$OPENC3_TAG ruby /openc3/bin/openc3cli $args
    set +a
    ;;
  start )
    ./openc3.sh build
    docker-compose -f compose.yaml -f compose-build.yaml build
    docker-compose -f compose.yaml up -d
    ;;
  stop )
    docker-compose -f compose.yaml down
    ;;
  cleanup )
    docker-compose -f compose.yaml down -v
    ;;
  build )
    scripts/linux/openc3_setup.sh
    docker-compose -f compose.yaml -f compose-build.yaml build openc3-ruby
    docker-compose -f compose.yaml -f compose-build.yaml build openc3-base
    docker-compose -f compose.yaml -f compose-build.yaml build openc3-node
    docker-compose -f compose.yaml -f compose-build.yaml build
    ;;
  run )
    docker-compose -f compose.yaml up -d
    ;;
  dev )
    docker-compose -f compose.yaml -f compose-dev.yaml up -d
    ;;
  deploy )
    scripts/linux/openc3_deploy.sh $2
    ;;
  test )
    scripts/linux/openc3_setup.sh
    docker-compose -f compose.yaml -f compose-build.yaml build
    scripts/linux/openc3_test.sh $2
    ;;
  util )
    scripts/linux/openc3_util.sh $2 $3
    ;;
  * )
    usage $0
    ;;
esac
