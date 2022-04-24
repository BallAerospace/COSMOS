#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

sudo mkdir -p /config
sudo cp $SCRIPT_DIR/../../../cosmos-redis/config/* /config/.

wget -O redis.tar.gz "https://download.redis.io/releases/redis-6.2.6.tar.gz"
echo "5b2b8b7a50111ef395bf1c1d5be11e6e167ac018125055daa8b5c2317ae131ab redis.tar.gz" | sha256sum --check --strict

sudo mkdir -p /usr/src/redis
sudo tar -xzvf redis.tar.gz -C /usr/src/redis --strip-components=1
rm redis.tar.gz

cd /usr/src/redis

sudo make
sudo make install

cd ~/
sudo rm -r /usr/src/redis
