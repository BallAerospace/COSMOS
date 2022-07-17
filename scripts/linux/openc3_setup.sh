#!/usr/bin/env sh

set -e

# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
# You may need to comment out the below three lines if you are on linux host (as opposed to mac)

# If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
# This will allow docker to work through local SSL infrastructure such as decryption devices

if [ ! -f ./cacert.pem ]; then
  if [ ! -z "$SSL_CERT_FILE" ]; then
    cp $SSL_CERT_FILE ./cacert.pem
    echo Using $SSL_CERT_FILE as cacert.pem
  else
    echo "Downloading cert from curl"
    curl -q -L https://curl.se/ca/cacert.pem --output ./cacert.pem
    if [ $? -ne 0 ]; then
      echo "ERROR: Problem downloading cacert.pem file from https://curl.se/ca/cacert.pem" 1>&2
      echo "openc3_setup FAILED" 1>&2
      exit 1
    else
      echo "Successfully downloaded ./cacert.pem file from: https://curl.se/ca/cacert.pem"
    fi
  fi
else
  echo "Using existing ./cacert.pem"
fi

cp ./cacert.pem openc3-ruby/cacert.pem
cp ./cacert.pem openc3-redis/cacert.pem
cp ./cacert.pem openc3-traefik/cacert.pem
cp ./cacert.pem openc3-minio/cacert.pem

docker --version
if [ "$?" -ne 0 ]; then
  echo "ERROR: docker is not installed, please install and try again." 1>&2
  echo "${0} FAILED" 1>&2
  exit 1
fi

docker-compose --version
if [ "$?" -ne 0 ]; then
  echo "ERROR: docker-compose is not installed, please install and try again." 1>&2
  echo "${0} FAILED" 1>&2
  exit 1
fi
