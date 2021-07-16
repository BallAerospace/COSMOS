@echo off

if ("%1"=="") (
  GOTO usage
)
if "%1" == "rspec" (
  GOTO rspec
)
if "%1" == "cypress" (
  GOTO cypress
)

GOTO usage

:rspec
  CD cosmos
  rspec
  CD ..
GOTO :EOF

:cypress
  REM Starting COSMOS
  docker-compose -f compose.yaml up -d
  CD cypress
  CALL yarn
  CALL yarn run fixwindows
  CALL yarn run cypress run
  CD ..
  REM Stopping COSMOS
  docker-compose -f compose.yaml down -v
GOTO :EOF

:usage
  @echo Usage: %1 [rspec, cypress] 1>&2
  @echo *  rspec: run tests against Ruby code 1>&2
  @echo *  cypress: run end-to-end tests 1>&2
@echo on
