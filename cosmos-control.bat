@echo off
setlocal ENABLEDELAYEDEXPANSION

if "%1" == "" (
  GOTO usage
)
if "%1" == "cosmos" (
  set params=%*
  call set params=%%params:*%1=%%
  REM Start (and remove when done --rm) the cosmos-base container with the current working directory
  REM mapped as volume (-v) /cosmos/local and container working directory (-w) also set to /cosmos/local.
  REM This allows tools running in the container to have a consistent path to the current working directory.
  REM Run the command "ruby /cosmos/bin/cosmos" with all parameters ignoring the first.
  docker run --rm -v %cd%:/cosmos/local -w /cosmos/local cosmos-base ruby /cosmos/bin/cosmos !params!
  GOTO :EOF
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
  docker-compose up -d
  @echo off
GOTO :EOF

:stop
  docker-compose down
  @echo off
GOTO :EOF

:cleanup
  docker-compose down -v
  @echo off
GOTO :EOF

:build
  CALL scripts/windows/cosmos_setup
  CALL scripts/windows/cosmos_build
  @echo off
GOTO :EOF

:run
  docker-compose up -d
  @echo off
GOTO :EOF

:deploy
  CALL scripts/windows/cosmos_deploy
  @echo off
GOTO :EOF

:restart
  docker-compose down
  docker-compose up -d
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
  @echo Usage: %0 [start, stop, cleanup, build, run, deploy, util] 1>&2
  @echo *  cosmos: run a cosmos command ('cosmos help' for more info) 1>&2
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
