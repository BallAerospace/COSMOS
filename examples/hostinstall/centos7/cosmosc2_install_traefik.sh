#!/bin/sh
set -eux

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

export TRAEFIK_DOWNLOAD_SHA256=5bf0e79b131b5f893d93c1912681deb1a49badb06218c234e43d3b0f7e3b8588

wget -O traefik.tar.gz "https://github.com/traefik/traefik/releases/download/v2.4.13/traefik_v2.4.13_linux_amd64.tar.gz"
echo "$TRAEFIK_DOWNLOAD_SHA256 *traefik.tar.gz" | sha256sum --check --strict

sudo mkdir -p /opt/traefik
sudo tar -zxvf traefik.tar.gz -C /opt/traefik
rm traefik.tar.gz

# Configure Traefik for COSMOS
sudo mkdir -p /etc/traefik
sudo cp $SCRIPT_DIR/traefik.yaml /etc/traefik/traefik.yaml
