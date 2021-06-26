@echo off

docker build -f cosmos-redis\Dockerfile -t ballaerospace/cosmosc2-redis cosmos-redis || exit /b
docker build -f cosmos-ruby\Dockerfile -t ballaerospace/cosmosc2-ruby cosmos-ruby || exit /b
docker build -f cosmos-node\Dockerfile -t ballaerospace/cosmosc2-node cosmos-node || exit /b
docker build -f cosmos\Dockerfile -t ballaerospace/cosmosc2-base cosmos || exit /b
docker build -f cosmos-cmd-tlm-api\Dockerfile -t ballaerospace/cosmosc2-cmd-tlm-api cosmos-cmd-tlm-api || exit /b
docker build -f cosmos-script-runner-api\Dockerfile -t ballaerospace/cosmosc2-script-runner-api cosmos-script-runner-api || exit /b
docker build -f cosmos-frontend-init\Dockerfile -t ballaerospace/cosmosc2-frontend-init cosmos-frontend-init || exit /b
docker build -f cosmos-traefik\Dockerfile -t ballaerospace/cosmosc2-traefik cosmos-traefik || exit /b
docker build -f cosmos-operator\Dockerfile -t ballaerospace/cosmosc2-operator cosmos-operator || exit /b
docker build -f cosmos-init\Dockerfile -t ballaerospace/cosmosc2-init cosmos-init || exit /b

@echo off
