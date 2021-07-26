#!/usr/bin/env sh

usage() {
  echo "Usage: $1 [encode, hash]" >&2
  echo "*  encode: encode a string to base64" >&2
  echo "*  hash: hash a string using SHA-256" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  usage $0
fi

case $1 in
  encode )
    echo -n $2 | base64
    ;;
  hash )
    echo -n $2 | shasum -a 256 | sed 's/-//'
    ;;
  * )
    usage $0
    ;;
esac
