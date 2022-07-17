#!/bin/sh

# To debug, uncomment OPENC3_REGISTRY line below
# docker run -d -p 5000:5000 --restart=always --name registry registry:2
# docker buildx create --use --name insecure-builder2 --driver-opt network=host --buildkitd-flags '--allow-insecure-entitlement security.insecure'

set -eux
OPENC3_PLATFORMS=linux/amd64,linux/arm64
cd ../..
eval $(sed -e '/^#/d' -e 's/^/export /' -e 's/$/;/' .env) ;
#OPENC3_REGISTRY=localhost:5000

# Setup cacert.pem
echo "Downloading cert from curl"
curl -q -L https://curl.se/ca/cacert.pem --output ./cacert.pem
if [ $? -ne 0 ]; then
  echo "ERROR: Problem downloading cacert.pem file from https://curl.se/ca/cacert.pem" 1>&2
  echo "openc3_setup FAILED" 1>&2
  exit 1
else
  echo "Successfully downloaded ./cacert.pem file from: https://curl.se/ca/cacert.pem"
fi

cp ./cacert.pem openc3-ruby/cacert.pem
cp ./cacert.pem openc3-redis/cacert.pem
cp ./cacert.pem openc3-traefik/cacert.pem
cp ./cacert.pem openc3-minio/cacert.pem

# Note: Missing OPENC3_REGISTRY build-arg intentionally to default to docker.io
cd openc3-ruby
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg ALPINE_VERSION=${ALPINE_VERSION} \
  --build-arg ALPINE_BUILD=${ALPINE_BUILD} \
  --build-arg APK_URL=${APK_URL} \
  --build-arg RUBYGEMS_URL=${RUBYGEMS_URL} \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-ruby:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg ALPINE_VERSION=${ALPINE_VERSION} \
  --build-arg ALPINE_BUILD=${ALPINE_BUILD} \
  --build-arg APK_URL=${APK_URL} \
  --build-arg RUBYGEMS_URL=${RUBYGEMS_URL} \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-ruby:latest .
fi

cd ../openc3-node
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-node:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-node:latest .
fi

cd ../openc3
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-base:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-base:latest .
fi

# Note: Missing OPENC3_REGISTRY build-arg intentionally to default to docker.io
cd ../openc3-redis
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-redis:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-redis:latest .
fi

# Note: Missing OPENC3_REGISTRY build-arg intentionally to default to docker.io
cd ../openc3-minio
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-minio:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-minio:latest .
fi

cd ../openc3-cmd-tlm-api
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-cmd-tlm-api:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-cmd-tlm-api:latest .
fi

cd ../openc3-script-runner-api
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-script-runner-api:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-script-runner-api:latest .
fi

cd ../openc3-operator
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-operator:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-operator:latest .
fi

# Note: Missing OPENC3_REGISTRY build-arg intentionally to default to docker.io
cd ../openc3-traefik
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-traefik:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-traefik:latest .
fi

cd ../openc3-init
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg NPM_URL=${NPM_URL} \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-init:${OPENC3_RELEASE_VERSION} .

if [ $OPENC3_UPDATE_LATEST = true ]
then
docker buildx build \
  --platform ${OPENC3_PLATFORMS} \
  --progress plain \
  --build-arg NPM_URL=${NPM_URL} \
  --build-arg OPENC3_REGISTRY=${OPENC3_REGISTRY} \
  --build-arg OPENC3_TAG=${OPENC3_RELEASE_VERSION} \
  --push -t ${OPENC3_REGISTRY}/openc3/openc3-init:latest .
fi
