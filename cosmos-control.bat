@echo off

if ("%1"=="") (
  GOTO usage
)
if "%1" == "config" (
  GOTO config
)
if "%1" == "start" (
  GOTO startup
)
if "%1" == "stop" (
  GOTO stop
)
if "%1" == "deploy" (
  GOTO deploy
)
if "%1" == "build" (
  GOTO build
)
if "%1" == "cleanup" (
  GOTO cleanup
)
if "%1" == "setup" (
  GOTO setup
)
GOTO usage

:config
  CALL scripts/windows/cosmos_config
  @echo off
GOTO :EOF

:setup
  CALL scripts/windows/cosmos_setup
  @echo off
GOTO :EOF

:deploy
  CALL scripts/windows/cosmos_deploy %2
  @echo off
GOTO :EOF

:cleanup
  CALL scripts/windows/cosmos_cleanup %2
  @echo off
GOTO :EOF

:build
  CALL scripts/windows/cosmos_setup
  CALL scripts/windows/cosmos_build %2
  @echo off
GOTO :EOF

:stop
  CALL scripts/windows/cosmos_stop %2
  @echo off
GOTO :EOF

:startup
  CALL scripts/windows/cosmos_setup
  CALL scripts/windows/cosmos_start %2
  @echo off
GOTO :EOF

:usage
  @echo Usage: %0 [config, setup, start, stop, cleanup, build, deploy] 1>&2
  @echo   All commands take a 'dev' option to start additional containers 1>&2
  @echo *  config: create a new COSMOS project configuration 1>&2
  @echo *  setup: setup containers to build and run 1>&2
  @echo *  start: run the minimal docker containers for cosmos 1>&2
  @echo *  stop: stop the running docker containers for cosmos 1>&2
  @echo *  cleanup: cleanup network and volumes for cosmos 1>&2
  @echo *  build: build the containers for cosmos 1>&2
  @echo *  deploy: deploy the containers to localhost repository 1>&2

@echo on
