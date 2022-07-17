@echo off

REM If necessary, before running please copy a local certificate authority .pem file as cacert.pem to this folder
REM This will allow docker to work through local SSL infrastructure such as decryption devices
if not exist .\cacert.pem (
  if DEFINED SSL_CERT_FILE (
    copy %SSL_CERT_FILE% .\cacert.pem
    echo Using %SSL_CERT_FILE% as cacert.pem
  ) else (
    echo "Downloading cacert.pem from curl"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://curl.se/ca/cacert.pem', '.\cacert.pem')"
    if errorlevel 1 (
      echo ERROR: Problem downloading .\cacert.pem file from https://curl.se/ca/cacert.pem
      echo openc3_start FAILED
      exit /b 1
    ) else (
      echo Successfully downloaded .\cacert.pem file from: https://curl.se/ca/cacert.pem
    )
  )
) else (
  echo Using existing cacert.pem
)

copy .\cacert.pem openc3-ruby\cacert.pem
copy .\cacert.pem openc3-redis\cacert.pem
copy .\cacert.pem openc3-traefik\cacert.pem
copy .\cacert.pem openc3-minio\cacert.pem

@echo on
