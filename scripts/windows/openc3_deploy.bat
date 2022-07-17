
if "%1" == "" (
  GOTO usage
)

@echo on
docker tag openc3/openc3-ruby %1/openc3-ruby:latest || exit /b
docker tag openc3/openc3-node %1/openc3-node:latest || exit /b
docker tag openc3/openc3-base %1/openc3-base:latest || exit /b
docker tag openc3/openc3-cmd-tlm-api %1/openc3-cmd-tlm-api:latest || exit /b
docker tag openc3/openc3-script-runner-api %1/openc3-script-runner-api:latest || exit /b
docker tag openc3/openc3-operator %1/openc3-operator:latest || exit /b
docker tag openc3/openc3-init %1/openc3-init:latest || exit /b
docker tag openc3/openc3-redis %1/openc3-redis:latest || exit /b
docker tag openc3/openc3-minio %1/openc3-minio:latest || exit /b

docker push %1/openc3-ruby:latest || exit /b
docker push %1/openc3-node:latest || exit /b
docker push %1/openc3-base:latest || exit /b
docker push %1/openc3-cmd-tlm-api:latest || exit /b
docker push %1/openc3-script-runner-api:latest || exit /b
docker push %1/openc3-operator:latest || exit /b
docker push %1/openc3-init:latest || exit /b
docker push %1/openc3-redis:latest || exit /b
docker push %1/openc3-minio:latest || exit /b

@echo off
GOTO :EOF


:usage
  @echo Usage: %0 [repository] 1>&2
  @echo *  repository: hostname of the docker repository 1>&2

@echo on