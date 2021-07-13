#!/bin/sh
set -e

/cosmos/minio/script-runner.sh

cd /cosmos/plugins/cosmos-demo/

rake build VERSION=5.0.0 --quiet

ruby /cosmos/bin/cosmos load /cosmos/plugins/cosmos-demo/cosmos-demo-5.0.0.*.gem
