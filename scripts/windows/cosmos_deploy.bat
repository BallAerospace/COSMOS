@echo on

REM Tag and push all the images to the local repository
docker tag ballaerospace/cosmosc2-ruby localhost:5000/cosmosc2-ruby:latest || exit /b
docker tag ballaerospace/cosmosc2-node localhost:5000/cosmosc2-node:latest || exit /b
docker tag ballaerospace/cosmosc2-base localhost:5000/cosmosc2-base:latest || exit /b
docker tag ballaerospace/cosmosc2-cmd-tlm-api localhost:5000/cosmosc2-cmd-tlm-api:latest || exit /b
docker tag ballaerospace/cosmosc2-script-runner-api localhost:5000/cosmosc2-script-runner-api:latest || exit /b
docker tag ballaerospace/cosmosc2-frontend-init localhost:5000/cosmosc2-frontend-init:latest || exit /b
docker tag ballaerospace/cosmosc2-operator localhost:5000/cosmosc2-operator:latest || exit /b
docker tag ballaerospace/cosmosc2-init localhost:5000/cosmosc2-init:latest || exit /b

docker push localhost:5000/cosmosc2-ruby:latest || exit /b
docker push localhost:5000/cosmosc2-node:latest || exit /b
docker push localhost:5000/cosmosc2-base:latest || exit /b
docker push localhost:5000/cosmosc2-cmd-tlm-api:latest || exit /b
docker push localhost:5000/cosmosc2-script-runner-api:latest || exit /b
docker push localhost:5000/cosmosc2-frontend-init:latest || exit /b
docker push localhost:5000/cosmosc2-operator:latest || exit /b
docker push localhost:5000/cosmosc2-init:latest || exit /b

@echo off
