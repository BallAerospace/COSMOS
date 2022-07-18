#!/bin/sh
set -eux

cd /usr/bin

sudo wget https://dl.min.io/server/minio/release/linux-amd64/minio
sudo chmod +x minio
sudo wget https://dl.min.io/client/mc/release/linux-amd64/mc
sudo chmod +x mc
