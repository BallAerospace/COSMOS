#!/usr/bin/env bash

read -p "This will remove all docker volumes which will delete **ALL** stored commands and telemetry! Are you sure (Y/[N])? " choice
case "$choice" in
  y|Y )
  docker volume rm cosmos-minio-v
  docker volume rm cosmos-redis-v
  docker volume rm cosmos-gems-v
  if [[ "$1" == "dev" ]]; then
    docker volume rm cosmos-elasticsearch-v
    docker volume rm cosmos-grafana-v
  fi
  docker network rm cosmos
  ;;
  * )
  ;;
esac
