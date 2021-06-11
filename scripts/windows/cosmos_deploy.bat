@echo on

REM Tag and push all the images to the local repository
docker tag cosmos-ruby localhost:5000/cosmos-ruby:latest || exit /b
docker tag cosmos-node localhost:5000/cosmos-node:latest || exit /b
docker tag cosmos-base localhost:5000/cosmos-base:latest || exit /b
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest || exit /b
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest || exit /b
docker tag cosmos-frontend-init localhost:5000/cosmos-frontend-init:latest || exit /b
docker tag cosmos-operator localhost:5000/cosmos-operator:latest || exit /b
docker tag cosmos-init localhost:5000/cosmos-init:latest || exit /b

docker push localhost:5000/cosmos-ruby:latest || exit /b
docker push localhost:5000/cosmos-node:latest || exit /b
docker push localhost:5000/cosmos-base:latest || exit /b
docker push localhost:5000/cosmos-cmd-tlm-api:latest || exit /b
docker push localhost:5000/cosmos-script-runner-api:latest || exit /b
docker push localhost:5000/cosmos-frontend-init:latest || exit /b
docker push localhost:5000/cosmos-operator:latest || exit /b
docker push localhost:5000/cosmos-init:latest || exit /b

@echo off
