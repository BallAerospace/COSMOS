@echo off

if ("%1"=="") (
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

GOTO usage

:encode
  powershell -c "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("""%2"""))"
GOTO :EOF

:hash
  powershell -c "new-object System.Security.Cryptography.SHA256Managed | ForEach-Object {$_.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("""%2"""))} | ForEach-Object {$_.ToString("""x2""")} | Write-Host -NoNewline"
GOTO :EOF

:save
  docker save ballaerospace/cosmosc2-redis -o cosmosc2-redis.tar || exit /b
  docker save minio/minio -o minio_minio.tar || exit /b
  docker save ballaerospace/cosmosc2-minio-init -o cosmosc2-minio-init.tar || exit /b
  docker save ballaerospace/cosmosc2-traefik -o cosmosc2-traefik.tar || exit /b
  docker save ballaerospace/cosmosc2-ruby -o cosmosc2-ruby.tar || exit /b
  docker save ballaerospace/cosmosc2-node -o cosmosc2-node.tar || exit /b
  docker save ballaerospace/cosmosc2-base -o cosmosc2-base.tar || exit /b
  docker save ballaerospace/cosmosc2-cmd-tlm-api -o cosmosc2-cmd-tlm-api.tar || exit /b
  docker save ballaerospace/cosmosc2-script-runner-api -o cosmosc2-script-runner-api.tar || exit /b
  docker save ballaerospace/cosmosc2-operator -o cosmosc2-operator.tar || exit /b
  docker save ballaerospace/cosmosc2-init  -o cosmosc2-init.tar || exit /b
GOTO :EOF

:load
  docker load -i cosmosc2-redis.tar || exit /b
  docker load -i minio_minio.tar || exit /b
  docker load -i cosmosc2-minio-init.tar || exit /b
  docker load -i cosmosc2-traefik.tar || exit /b
  docker load -i cosmosc2-ruby.tar || exit /b
  docker load -i cosmosc2-node.tar || exit /b
  docker load -i cosmosc2-base.tar || exit /b
  docker load -i cosmosc2-cmd-tlm-api.tar || exit /b
  docker load -i cosmosc2-script-runner-api.tar || exit /b
  docker load -i cosmosc2-operator.tar || exit /b
  docker load -i cosmosc2-init.tar || exit /b
GOTO :EOF

:zip
  zip -r cosmos.zip *.* -x "*.git*" -x "*coverage*" -x "*tmp/cache*" -x "*node_modules*" -x "*yarn.lock"
GOTO :EOF

:usage
  @echo Usage: %1 [encode, hash, save, load] 1>&2
  @echo *  encode: encode a string to base64 1>&2
  @echo *  hash: hash a string using SHA-256 1>&2
  @echo *  save: save cosmos to tar files 1>&2
  @echo *  load: load cosmos tar files 1>&2
  @echo *  zip: create cosmos zipfile 1>&2

@echo on
