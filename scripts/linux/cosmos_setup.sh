#!/usr/bin/env sh

# Please download cacert.pem from https://curl.haxx.se/docs/caextract.html and place in this folder before running
# Alternatively, if your org requires a different certificate authority file, please place that here as cacert.pem before running
# This will allow docker to work through local SSL infrastructure such as decryption devices
# You may need to comment out the below three lines if you are on linux host (as opposed to mac)

# If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
# This will allow docker to work through local SSL infrastructure such as decryption devices

if [ ! -f cosmos-ruby/cacert.pem ]; then
  if [ ! -z "$SSL_CERT_FILE" ]; then
    cp $SSL_CERT_FILE cosmos-ruby/cacert.pem
    echo Using $SSL_CERT_FILE as cacert.pem
  else
    echo "Downloading cert from curl"
    curl -q -L https://curl.se/ca/cacert.pem --output cosmos-ruby/cacert.pem
    if [ $? -ne 0 ]; then
      echo "ERROR: Problem downloading cacert.pem file from https://curl.se/ca/cacert.pem" 1>&2
      echo "cosmos_setup FAILED" 1>&2
      exit 1
    else
      echo "Successfully downloaded cosmos-ruby/cacert.pem file from: https://curl.se/ca/cacert.pem"
    fi
  fi
else
  echo "Using existing cosmos-ruby/cacert.pem"
fi

docker-compose -v
if [ $? -ne 0 ]; then
  echo "ERROR: docker-compose is not installed, please install and try again." 1>&2
  echo "cosmos_setup FAILED" 1>&2
  exit 1
fi

# These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"