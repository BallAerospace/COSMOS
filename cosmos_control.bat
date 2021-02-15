
@echo off

if ("%1"=="") (
  GOTO usage
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

if "%1" == "start_dev" (
  GOTO start_dev
)

GOTO usage

:setup
  CALL scripts/windows/cosmos_setup
  @echo off
GOTO :EOF

:deploy
  CALL scripts/windows/cosmos_deploy
  @echo off
GOTO :EOF

:cleanup
  CALL scripts/windows/cosmos_cleanup
  @echo off
GOTO :EOF

:build
  CALL scripts/windows/cosmos_setup
  @echo off
  CALL scripts/windows/cosmos_build
  @echo off
GOTO :EOF

:stop
  CALL scripts/windows/cosmos_stop
  @echo off
GOTO :EOF

:startup
  CALL scripts/windows/cosmos_setup
  @echo off
  CALL scripts/windows/cosmos_minimal_start
  @echo off
GOTO :EOF

:start_dev
  CALL scripts/windows/cosmos_setup
  @echo off
  CALL scripts/windows/cosmos_start
  @echo off
GOTO :EOF

:usage
  @echo Usage: %0 [setup, start, stop, cleanup, build, deploy, start_dev] 1>&2
  @echo *  setup: setup containers to build and run 1>&2
  @echo *  start: run the minimal docker containers for cosmos 1>&2
  @echo *  stop: stop the running docker containers for cosmos 1>&2
  @echo *  cleanup: cleanup network and volumes for cosmos 1>&2
  @echo *  build: build the containers for cosmos 1>&2
  @echo *  deploy: deploy the containers to localhost repository 1>&2
  @echo *  start_dev: run all docker containers for cosmos 1>&2

@echo on