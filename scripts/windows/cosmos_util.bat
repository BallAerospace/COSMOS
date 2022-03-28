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
if "%1" == "clean" (
  GOTO clean
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
  docker save minio/minio -o tmp/minio_minio.tar || exit /b
  docker save ballaerospace/cosmosc2-redis -o tmp/cosmosc2-redis.tar || exit /b
  docker save ballaerospace/cosmosc2-minio-init -o tmp/cosmosc2-minio-init.tar || exit /b
  docker save ballaerospace/cosmosc2-traefik -o tmp/cosmosc2-traefik.tar || exit /b
  docker save ballaerospace/cosmosc2-ruby -o tmp/cosmosc2-ruby.tar || exit /b
  docker save ballaerospace/cosmosc2-node -o tmp/cosmosc2-node.tar || exit /b
  docker save ballaerospace/cosmosc2-base -o tmp/cosmosc2-base.tar || exit /b
  docker save ballaerospace/cosmosc2-cmd-tlm-api -o tmp/cosmosc2-cmd-tlm-api.tar || exit /b
  docker save ballaerospace/cosmosc2-script-runner-api -o tmp/cosmosc2-script-runner-api.tar || exit /b
  docker save ballaerospace/cosmosc2-operator -o tmp/cosmosc2-operator.tar || exit /b
  docker save ballaerospace/cosmosc2-init  -o tmp/cosmosc2-init.tar || exit /b
GOTO :EOF

:load
  docker load -i tmp/minio_minio.tar || exit /b
  docker load -i tmp/cosmosc2-redis.tar || exit /b
  docker load -i tmp/cosmosc2-minio-init.tar || exit /b
  docker load -i tmp/cosmosc2-traefik.tar || exit /b
  docker load -i tmp/cosmosc2-ruby.tar || exit /b
  docker load -i tmp/cosmosc2-node.tar || exit /b
  docker load -i tmp/cosmosc2-base.tar || exit /b
  docker load -i tmp/cosmosc2-cmd-tlm-api.tar || exit /b
  docker load -i tmp/cosmosc2-script-runner-api.tar || exit /b
  docker load -i tmp/cosmosc2-operator.tar || exit /b
  docker load -i tmp/cosmosc2-init.tar || exit /b
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

:usage
  @echo Usage: %1 [encode, hash, save, load] 1>&2
  @echo *  encode: encode a string to base64 1>&2
  @echo *  hash: hash a string using SHA-256 1>&2
  @echo *  save: save cosmos to tar files 1>&2
  @echo *  load: load cosmos tar files 1>&2
  @echo *  zip: create cosmos zipfile 1>&2
  @echo *  clean: remove node_modules, coverage, etc 1>&2

@echo on
