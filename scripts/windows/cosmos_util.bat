@echo off

if "%1" == "" (
  GOTO usage
)
if "%1" == "encode" (
  GOTO encode
)
if "%1" == "hash" (
  GOTO hash
)
if "%1" == "save" (
  GOTO save
)
if "%1" == "load" (
  GOTO load
)
if "%1" == "zip" (
  GOTO zip
)
if "%1" == "clean" (
  GOTO clean
)
if "%1" == "hostsetup" (
  GOTO hostsetup
)

GOTO usage

:encode
  powershell -c "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("""%2"""))"
GOTO :EOF

:hash
  powershell -c "new-object System.Security.Cryptography.SHA256Managed | ForEach-Object {$_.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("""%2"""))} | ForEach-Object {$_.ToString("""x2""")} | Write-Host -NoNewline"
GOTO :EOF

:save
  if not exist tmp md tmp
  if "%2" == "" (
    set tag=latest
  ) else (
    set tag=%2
  )
  echo on
  docker pull minio/minio  || exit /b
  docker save minio/minio -o tmp/minio_minio.tar || exit /b
  docker pull ballaerospace/cosmosc2-redis:%tag% || exit /b
  docker save ballaerospace/cosmosc2-redis:%tag% -o tmp/cosmosc2-redis-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-minio-init:%tag% || exit /b
  docker save ballaerospace/cosmosc2-minio-init:%tag% -o tmp/cosmosc2-minio-init-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-traefik:%tag% || exit /b
  docker save ballaerospace/cosmosc2-traefik:%tag% -o tmp/cosmosc2-traefik-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-ruby:%tag% || exit /b
  docker save ballaerospace/cosmosc2-ruby:%tag% -o tmp/cosmosc2-ruby-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-node:%tag% || exit /b
  docker save ballaerospace/cosmosc2-node:%tag% -o tmp/cosmosc2-node-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-base:%tag% || exit /b
  docker save ballaerospace/cosmosc2-base:%tag% -o tmp/cosmosc2-base-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-cmd-tlm-api:%tag% || exit /b
  docker save ballaerospace/cosmosc2-cmd-tlm-api:%tag% -o tmp/cosmosc2-cmd-tlm-api-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-script-runner-api:%tag% || exit /b
  docker save ballaerospace/cosmosc2-script-runner-api:%tag% -o tmp/cosmosc2-script-runner-api-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-operator:%tag% || exit /b
  docker save ballaerospace/cosmosc2-operator:%tag% -o tmp/cosmosc2-operator-%tag%.tar || exit /b
  docker pull ballaerospace/cosmosc2-init:%tag% || exit /b
  docker save ballaerospace/cosmosc2-init:%tag% -o tmp/cosmosc2-init-%tag%.tar || exit /b
  echo off
GOTO :EOF

:load
  if "%2" == "" (
    set tag=latest
  ) else (
    set tag=%2
  )
  echo on
  docker load -i tmp/minio_minio.tar || exit /b
  docker load -i tmp/cosmosc2-redis-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-minio-init-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-traefik-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-ruby-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-node-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-base-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-cmd-tlm-api-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-script-runner-api-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-operator-%tag%.tar || exit /b
  docker load -i tmp/cosmosc2-init-%tag%.tar || exit /b
  echo off
GOTO :EOF

:zip
  zip -r cosmos.zip *.* -x "*.git*" -x "*coverage*" -x "*tmp/cache*" -x "*node_modules*" -x "*yarn.lock"
GOTO :EOF

:clean
  for /d /r %%i in (*node_modules*) do (
    echo Removing "%%i"
    @rmdir /s /q "%%i"
  )
  for /d /r %%i in (*coverage*) do (
    echo Removing "%%i"
    @rmdir /s /q "%%i"
  )
  REM Prompt for removing yarn.lock files
  forfiles /S /M yarn.lock /C "cmd /c del /P @path"
  REM Prompt for removing Gemfile.lock files
  forfiles /S /M Gemfile.lock /C "cmd /c del /P @path"
GOTO :EOF

:hostsetup
  docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled" || exit /b
  docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag" || exit /b
  docker run --rm --privileged --pid=host justincormack/nsenter1 /bin/sh -c "sysctl -w vm.max_map_count=262144" || exit /b
GOTO :EOF

:usage
  @echo Usage: %1 [encode, hash, save, load, clean, redishost] 1>&2
  @echo *  encode: encode a string to base64 1>&2
  @echo *  hash: hash a string using SHA-256 1>&2
  @echo *  save: save cosmos to tar files 1>&2
  @echo *  load: load cosmos tar files 1>&2
  @echo *  zip: create cosmos zipfile 1>&2
  @echo *  clean: remove node_modules, coverage, etc 1>&2
  @echo *  hostsetup: configure host for redis 1>&2

@echo on
