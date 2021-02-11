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

REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144"

docker build -f cosmos\Dockerfile -t cosmos-base cosmos

docker build -f geminabox\Dockerfile -t cosmos-gems geminabox

docker build -f cmd_tlm_api\Dockerfile -t cosmos-cmd-tlm-api cmd_tlm_api

docker build -f script_runner_api\Dockerfile -t cosmos-script-runner-api script_runner_api

docker build -f frontend\Dockerfile -t cosmos-frontend frontend

docker build -f aggregator\Dockerfile -t cosmos-aggregator aggregator

docker build -f operator\Dockerfile -t cosmos-operator operator

docker build -f init\Dockerfile -t cosmos-init init

REM Push all the images to the local repository
docker push localhost:5000/cosmos-base:latest

docker push localhost:5000/cosmos-gems:latest

docker push localhost:5000/cosmos-cmd-tlm-api:latest

docker push localhost:5000/cosmos-script-runner-api:latest

docker push localhost:5000/cosmos-frontend:latest

docker push localhost:5000/cosmos-aggregator:latest

docker push localhost:5000/cosmos-operator:latest

docker push localhost:5000/cosmos-init:latest
