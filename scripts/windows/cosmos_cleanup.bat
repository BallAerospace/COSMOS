
@echo off
:PROMPT
SET /P "question=This will remove all files. Are you sure (Y/[N])? "
IF /I "%question%" NEQ "Y" GOTO :EOF

:cleanup
@echo on
docker volume rm cosmos-elasticsearch-v
docker volume rm cosmos-grafana-v
docker volume rm cosmos-minio-v
docker volume rm cosmos-redis-v
docker volume rm cosmos-gems-v
docker network rm cosmos