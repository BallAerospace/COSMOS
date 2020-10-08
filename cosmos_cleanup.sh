#!/usr/bin/env bash
docker volume rm cosmos-elasticsearch-v
docker volume rm cosmos-minio-v
docker volume rm cosmos-redis-v
docker volume rm cosmos-gems-v
docker network rm cosmos