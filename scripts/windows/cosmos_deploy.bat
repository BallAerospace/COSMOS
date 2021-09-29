
if "%1" == "" (
  GOTO usage
)

@echo on
docker tag ballaerospace/cosmosc2-ruby %1/cosmosc2-ruby:latest || exit /b
docker tag ballaerospace/cosmosc2-node %1/cosmosc2-node:latest || exit /b
docker tag ballaerospace/cosmosc2-base %1/cosmosc2-base:latest || exit /b
docker tag ballaerospace/cosmosc2-cmd-tlm-api %1/cosmosc2-cmd-tlm-api:latest || exit /b
docker tag ballaerospace/cosmosc2-script-runner-api %1/cosmosc2-script-runner-api:latest || exit /b
docker tag ballaerospace/cosmosc2-operator %1/cosmosc2-operator:latest || exit /b
docker tag ballaerospace/cosmosc2-init %1/cosmosc2-init:latest || exit /b
docker tag ballaerospace/cosmosc2-redis %1/cosmosc2-redis:latest || exit /b

docker push %1/cosmosc2-ruby:latest || exit /b
docker push %1/cosmosc2-node:latest || exit /b
docker push %1/cosmosc2-base:latest || exit /b
docker push %1/cosmosc2-cmd-tlm-api:latest || exit /b
docker push %1/cosmosc2-script-runner-api:latest || exit /b
docker push %1/cosmosc2-operator:latest || exit /b
docker push %1/cosmosc2-init:latest || exit /b
docker push %1/cosmosc2-redis:latest || exit /b

@echo off
GOTO :EOF


:usage
  @echo Usage: %0 [repository] 1>&2
  @echo *  repository: hostname of the docker repository 1>&2

@echo on