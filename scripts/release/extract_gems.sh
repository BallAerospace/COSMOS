#!/bin/sh
set -eux

id=$(docker create $OPENC3_REGISTRY/ballaerospace/openc3-base:$OPENC3_RELEASE_VERSION)
docker cp $id:/openc3/gems/. .
docker rm -v $id

id=$(docker create $OPENC3_REGISTRY/ballaerospace/openc3-init:$OPENC3_RELEASE_VERSION)
docker cp $id:/openc3/plugins/gems/. .
docker rm -v $id

ls *.gem
