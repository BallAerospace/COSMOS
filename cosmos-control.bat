@echo off

if ("%1"=="") (
  GOTO usage
)
if "%1" == "restart" (
  GOTO restart
)
if "%1" == "start" (
  GOTO startup
)
if "%1" == "stop" (
  GOTO stop
)
if "%1" == "cleanup" (
  GOTO cleanup
)
if "%1" == "build" (
  GOTO build
)
if "%1" == "run" (
  GOTO run
)
if "%1" == "deploy" (
  GOTO deploy
)
if "%1" == "util" (
  GOTO util
)

GOTO usage

:startup
  CALL scripts/windows/cosmos_setup
  CALL scripts/windows/cosmos_build
  CALL scripts/windows/cosmos_run
  @echo off
GOTO :EOF

:stop
  CALL scripts/windows/cosmos_stop
  @echo off
GOTO :EOF

:cleanup
  CALL scripts/windows/cosmos_cleanup
  @echo off
GOTO :EOF

:build
  CALL scripts/windows/cosmos_setup
  CALL scripts/windows/cosmos_build
  @echo off
GOTO :EOF

:run
  CALL scripts/windows/cosmos_run
  @echo off
GOTO :EOF

:deploy
  CALL scripts/windows/cosmos_deploy
  @echo off
GOTO :EOF

:restart
  CALL scripts/windows/cosmos_restart
  @echo off
GOTO :EOF

:util
  REM Send the remaining arguments to cosmos_util
  set args=%*
  call set args=%%args:*%1=%%
  CALL scripts/windows/cosmos_util %args%
  @echo off
GOTO :EOF

:usage
  @echo Usage: %0 [start, stop, cleanup, build, run, deploy] 1>&2
  @echo *  start: run the docker containers for cosmos 1>&2
  @echo *  stop: stop the running docker containers for cosmos 1>&2
  @echo *  restart: stop and run the minimal docker containers for cosmos 1>&2
  @echo *  cleanup: cleanup network and volumes for cosmos 1>&2
  @echo *  build: build the containers for cosmos 1>&2
  @echo *  run: run the prebuilt containers for cosmos 1>&2
  @echo *  deploy: deploy the containers to localhost repository 1>&2
  @echo *  util: various helper commands: 1>&2
  @echo *    encode: encode a string to base64 1>&2
  @echo *    hash: hash a string using SHA-256 1>&2

@echo on
