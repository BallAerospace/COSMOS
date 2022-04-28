#!/bin/sh

# To debug, uncomment COSMOS_REGISTRY line below
# docker run -d -p 5000:5000 --restart=always --name registry registry:2
# docker buildx create --use --name insecure-builder2 --driver-opt network=host --buildkitd-flags '--allow-insecure-entitlement security.insecure'

set -eux
COSMOS_PLATFORMS=linux/amd64,linux/arm64
cd ../..
eval $(sed -e '/^#/d' -e 's/^/export /' -e 's/$/;/' .env) ;
COSMOS_REGISTRY=localhost:5000

# Note: Missing COSMOS_REGISTRY build-arg intentionally to default to docker.io
cd cosmos-ruby
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg ALPINE_VERSION=${ALPINE_VERSION} \
  --build-arg ALPINE_BUILD=${ALPINE_BUILD} \
  --build-arg APK_URL=${APK_URL} \
  --build-arg RUBYGEMS_URL=${RUBYGEMS_URL} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-ruby:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg ALPINE_VERSION=${ALPINE_VERSION} \
  --build-arg ALPINE_BUILD=${ALPINE_BUILD} \
  --build-arg APK_URL=${APK_URL} \
  --build-arg RUBYGEMS_URL=${RUBYGEMS_URL} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-ruby:latest .
fi

cd ../cosmos-node
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-node:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-node:latest .
fi

cd ../cosmos
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-base:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-base:latest .
fi

# Note: Missing COSMOS_REGISTRY build-arg intentionally to default to docker.io
cd ../cosmos-minio-init
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-minio-init:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-minio-init:latest .
fi

# Note: Missing COSMOS_REGISTRY build-arg intentionally to default to docker.io
cd ../cosmos-redis
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-redis:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-redis:latest .
fi

cd ../cosmos-cmd-tlm-api
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-cmd-tlm-api:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-cmd-tlm-api:latest .
fi

cd ../cosmos-script-runner-api
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-script-runner-api:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-script-runner-api:latest .
fi

cd ../cosmos-operator
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-operator:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-operator:latest .
fi

# Note: Missing COSMOS_REGISTRY build-arg intentionally to default to docker.io
cd ../cosmos-traefik
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-traefik:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-traefik:latest .
fi

cd ../cosmos-init
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --build-arg NPM_URL=${NPM_URL} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-init:${COSMOS_RELEASE_VERSION} .

if [ $COSMOS_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${COSMOS_PLATFORMS} \
  --build-arg COSMOS_REGISTRY=${COSMOS_REGISTRY} \
  --build-arg NPM_URL=${NPM_URL} \
  --push -t ${COSMOS_REGISTRY}/ballaerospace/cosmosc2-init:latest .
fi
