@echo off

REM If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
REM This will allow docker to work through local SSL infrastructure such as decryption devices
if not exist cosmos-ruby\cacert.pem (
  if DEFINED SSL_CERT_FILE (
    copy %SSL_CERT_FILE% cosmos-ruby\cacert.pem
    echo Using %SSL_CERT_FILE% as cacert.pem
  ) else (
    echo "Downloading cacert.pem from curl"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://curl.se/ca/cacert.pem', 'cosmos-ruby\cacert.pem')"
    if errorlevel 1 (
      echo ERROR: Problem downloading cosmos-ruby\cacert.pem file from https://curl.se/ca/cacert.pem
      echo cosmos_start FAILED
      exit /b 1
    ) else (
      echo Successfully downloaded cosmos-ruby\cacert.pem file from: https://curl.se/ca/cacert.pem
    )
  )
) else (
  echo Using existing cacert.pem
)

if not DEFINED RUBYGEMS_URL (
  set RUBYGEMS_URL=https://rubygems.org
)
echo RUBYGEMS_URL set to %RUBYGEMS_URL%

if not DEFINED NPM_URL (
  set NPM_URL=https://registry.npmjs.org
)
echo NPM_URL set to %NPM_URL%

if not DEFINED APK_URL (
  set APK_URL=http://dl-cdn.alpinelinux.org
)
echo APK_URL set to %APK_URL%


REM These lines configure the host OS properly for Redis
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
docker run -it --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b

@echo on
