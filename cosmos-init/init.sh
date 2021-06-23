#!/bin/sh
set -e

export COSMOS_REDIS_URL=redis://cosmos-redis:6379
export COSMOS_REDIS_HOST=cosmos-redis:6379
export COSMOS_REDIS_USERNAME=cosmos
export COSMOS_REDIS_PASSWORD=cosmospassword

ruby /cosmos/bin/cosmos load /cosmos/plugins/cosmos-demo/cosmos-demo-5.0.0.*.gem
