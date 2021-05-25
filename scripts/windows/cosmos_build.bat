@echo off

docker build -f cosmos-ruby\Dockerfile -t cosmos-ruby cosmos-ruby || exit /b
docker build -f cosmos-node\Dockerfile -t cosmos-node cosmos-node || exit /b
docker build -f cosmos\Dockerfile -t cosmos-base cosmos || exit /b
docker build -f cosmos-cmd-tlm-api\Dockerfile -t cosmos-cmd-tlm-api cosmos-cmd-tlm-api || exit /b
docker build -f cosmos-script-runner-api\Dockerfile -t cosmos-script-runner-api cosmos-script-runner-api || exit /b
docker build -f cosmos-frontend-init\Dockerfile -t cosmos-frontend-init cosmos-frontend-init || exit /b
docker build -f traefik\Dockerfile -t cosmos-traefik traefik || exit /b
docker build -f cosmos-operator\Dockerfile -t cosmos-operator cosmos-operator || exit /b
docker build -f cosmos-init\Dockerfile -t cosmos-init cosmos-init || exit /b

@echo off
