#!/bin/sh
set -eux

id=$(docker create $COSMOS_REGISTRY/ballaerospace/cosmosc2-base:$COSMOS_RELEASE_VERSION)
docker cp $id:/cosmos/gems/. .
docker rm -v $id

id=$(docker create $COSMOS_REGISTRY/ballaerospace/cosmosc2-init:$COSMOS_RELEASE_VERSION)
docker cp $id:/cosmos/plugins/gems/. .
docker rm -v $id

ls *.gem
