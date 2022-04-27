#!/bin/sh
set -eux

id=$(docker create ballaerospace/cosmosc2-base)
docker cp $id:/cosmos/gems/. .
docker rm -v $id

id=$(docker create ballaerospace/cosmosc2-init)
docker cp $id:/cosmos/plugins/gems/. .
docker rm -v $id
