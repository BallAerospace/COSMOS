@echo off
REM If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
REM This will allow docker to work through local SSL infrastructure such as decryption devices
if not exist cacert.pem (
  if exist C:\ProgramData\BATC\GlobalSign.pem (
    copy C:\ProgramData\BATC\GlobalSign.pem cacert.pem
    echo Using existing Ball GlobalSign.pem as cacert.pem
  ) else (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://curl.haxx.se/ca/cacert.pem', 'cacert.pem')"
    if errorlevel 1 (
      echo ERROR: Problem downloading cacert.pem file from https://curl.haxx.se/ca/cacert.pem
      echo cosmos_start FAILED
      exit /b 1
    ) else (
      echo Successfully downloaded cacert.pem file from: https://curl.haxx.se/ca/cacert.pem
    )
  )
) else (
  echo Using existing cacert.pem
)
@echo on
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"
REM docker network create cosmos
docker build -f Dockerfile.cosmos_base -t cosmos-base .
docker push cosmos-base
docker tag cosmos-base localhost:5000/cosmos-base:latest
cd web\geminabox && docker build -t cosmos-gems .
docker tag cosmos-gems localhost:5000/cosmos-gems:latest
cd ..\..
del web\cmd_tlm_api\Gemfile.lock
docker build -f Dockerfile.cmd_tlm_api -t cosmos-cmd-tlm-api .
docker tag cosmos-cmd-tlm-api localhost:5000/cosmos-cmd-tlm-api:latest
del web\script_runner_api\Gemfile.lock
docker build -f Dockerfile.script_runner_api -t cosmos-script-runner-api .
docker tag cosmos-script-runner-api localhost:5000/cosmos-script-runner-api:latest
docker build -f Dockerfile.frontend -t cosmos-frontend .
docker tag cosmos-frontend localhost:5000/cosmos-frontend:latest
docker build -f Dockerfile.operator -t cosmos-operator .
docker tag cosmos-operator localhost:5000/cosmos-operator:latest
docker build -f Dockerfile.init -t cosmos-init .
docker tag cosmos-init localhost:5000/cosmos-init:latest

REM Push all the images to the local repository
docker push localhost:5000/cosmos-base:latest
docker push localhost:5000/cosmos-gems:latest
docker push localhost:5000/cosmos-cmd-tlm-api:latest
docker push localhost:5000/cosmos-script-runner-api:latest
docker push localhost:5000/cosmos-frontend:latest
docker push localhost:5000/cosmos-operator:latest
docker push localhost:5000/cosmos-init:latest
