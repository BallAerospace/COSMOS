#!/bin/sh
set -eux

export NOKOGIRI_USE_SYSTEM_LIBRARIES=1

export RUBYGEMS_URL=https://rubygems.org
export NPM_URL=https://registry.npmjs.org

export SECRET_KEY_BASE=bdb4300d46c9d4f116ce3dbbd54cac6b20802d8be1c2333cf5f6f90b1627799ac5d043e8460744077bc0bd6aacdd5c4bf53f499a68303c6752e7f327b874b96a
export COSMOS_REDIS_HOSTNAME=localhost
export COSMOS_REDIS_PORT=6379
export COSMOS_S3_URL=http://localhost:9000

export COSMOS_REDIS_USERNAME=cosmos
export COSMOS_REDIS_PASSWORD=cosmospassword

export COSMOS_MINIO_USERNAME=cosmosminio
export COSMOS_MINIO_PASSWORD=cosmosminiopassword

export COSMOS_SERVICE_PASSWORD=cosmosservice

export COSMOS_SR_REDIS_USERNAME=scriptrunner
export COSMOS_SR_REDIS_PASSWORD=scriptrunnerpassword
export COSMOS_SR_MINIO_USERNAME=scriptrunnerminio
export COSMOS_SR_MINIO_PASSWORD=scriptrunnerminiopassword

export COSMOS_TAG=latest

export COSMOS_DEMO=1

export RUBYLIB=/cosmos/lib
export COSMOS_PATH=/cosmos
