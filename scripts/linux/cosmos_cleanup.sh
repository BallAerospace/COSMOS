#!/usr/bin/env bash

read -p "This will remove all files. Are you sure (y/[N])? " choice
case "$choice" in
  y|Y )
  docker volume rm cosmos-elasticsearch-v
  docker volume rm cosmos-grafana-v
  docker volume rm cosmos-minio-v
  docker volume rm cosmos-redis-v
  docker volume rm cosmos-gems-v
  docker network rm cosmos
  ;;
  * )
  ;;
esac
