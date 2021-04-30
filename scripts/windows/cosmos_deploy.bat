@echo on

REM Tag and push all the images to the local repository
docker tag cosmos-base localhost:5000/cosmos-base:latest || exit /b
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest || exit /b
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest || exit /b
docker tag cosmos-frontend-init localhost:5000/cosmos-frontend-init:latest || exit /b
docker tag cosmos-operator localhost:5000/cosmos-operator:latest || exit /b
docker tag cosmos-init localhost:5000/cosmos-init:latest || exit /b

docker push localhost:5000/cosmos-base:latest || exit /b
docker push localhost:5000/cosmos-cmd-tlm-api:latest || exit /b
docker push localhost:5000/cosmos-script-runner-api:latest || exit /b
docker push localhost:5000/cosmos-frontend-init:latest || exit /b
docker push localhost:5000/cosmos-operator:latest || exit /b
docker push localhost:5000/cosmos-init:latest || exit /b

@echo off
if "%1" == "dev" (
  @echo on
  docker tag cosmos-elasticsearch localhost:5000/cosmos-elasticsearch:latest || exit /b
  docker tag cosmos-kibana localhost:5000/cosmos-kibana:latest || exit /b
  docker tag cosmos-fluentd localhost:5000/cosmos-fluentd:latest || exit /b
  docker tag cosmos-grafana localhost:5000/cosmos-grafana:latest || exit /b
  docker tag cosmos-prometheus localhost:5000/cosmos-prometheus:latest || exit /b

  docker push localhost:5000/cosmos-elasticsearch:latest || exit /b
  docker push localhost:5000/cosmos-kibana:latest || exit /b
  docker push localhost:5000/cosmos-fluentd:latest || exit /b
  docker push localhost:5000/cosmos-grafana:latest || exit /b
  docker push localhost:5000/cosmos-prometheus:latest || exit /b
)
