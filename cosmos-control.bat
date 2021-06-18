@echo off
setlocal ENABLEDELAYEDEXPANSION

if "%1" == "" (
  GOTO usage
)
if "%1" == "cosmos" (
  set params=%*
  call set params=%%params:*%1=%%
  REM Start (and remove when done --rm) the cosmos-base container with the current working directory
  REM mapped as volume (-v) /cosmos/plugins and container working directory (-w) also set to /cosmos/plugins
  REM and run the command "ruby /cosmos/bin/cosmos" with all parameters ignoring the first
  docker run --rm -v %cd%:/cosmos/plugins -w /cosmos/plugins cosmos-base ruby /cosmos/bin/cosmos !params!
  GOTO :EOF
)
if "%1" == "rake" (
  @REM set params=%*
  @REM call set params=%%params:*%1=%%
  docker run --rm -v %cd%:/cosmos -w /cosmos cosmos-base %1
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

:usage
  @echo Usage: %0 [start, stop, cleanup, build, run, deploy] 1>&2
  @echo *  cosmos: run a cosmos command ('cosmos help' for more info) 1>&2
  @echo *  start: run the docker containers for cosmos 1>&2
  @echo *  stop: stop the running docker containers for cosmos 1>&2
  @echo *  restart: stop and run the minimal docker containers for cosmos 1>&2
  @echo *  cleanup: cleanup network and volumes for cosmos 1>&2
  @echo *  build: build the containers for cosmos 1>&2
  @echo *  run: run the prebuilt containers for cosmos 1>&2
  @echo *  deploy: deploy the containers to localhost repository 1>&2

@echo on
