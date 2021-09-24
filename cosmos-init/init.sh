#!/bin/sh
set -e

/cosmos/minio/script-runner.sh

ruby /cosmos/bin/cosmos load /cosmos/plugins/cosmos-demo/cosmos-demo-5.0.0.*.gem
