#!/usr/bin/env bash

# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
# You may need to comment out the below three lines if you are on linux host (as opposed to mac)

# If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
# This will allow docker to work through local SSL infrastructure such as decryption devices

if [ ! -f cacert.pem ]; then
  if [ ! -z "$SSL_CERT_FILE" ]; then
    cp $SSL_CERT_FILE cosmos-ruby\cacert.pem
    echo Using $SSL_CERT_FILE as cacert.pem
  else
    echo "Downloading cert from curl"
    curl -q https://curl.haxx.se/ca/cacert.pem --output cacert.pem
    if [ $? -ne 0 ]; then
      echo "ERROR: Problem downloading cacert.pem file from https://curl.haxx.se/ca/cacert.pem" >&2
      echo "cosmos_setup FAILED" >&2
      exit 1
    else
      echo "Successfully downloaded cacert.pem file from: https://curl.haxx.se/ca/cacert.pem"
      cp cacert.pem cosmos-ruby/cacert.pem
    fi
  fi
else
  echo Using existing cacert.pem
  cp cacert.pem cosmos-ruby/cacert.pem
fi
