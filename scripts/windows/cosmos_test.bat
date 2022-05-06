@echo off

if ("%1" == "") (
  GOTO usage
)
if "%1" == "rspec" (
  GOTO rspec
)
if "%1" == "playwright" (
  GOTO playwright
)

GOTO usage

:rspec
  CD cosmos
  rspec
  CD ..
GOTO :EOF

:playwright
  REM Starting COSMOS
  docker-compose -f compose.yaml up -d
  CD playwright
  CALL yarn run fixwindows
  CALL yarn playwright test
  CALL yarn coverage
  CD ..
GOTO :EOF

:usage
  @echo Usage: %1 [rspec, playwright] 1>&2
  @echo *  rspec: run tests against Ruby code 1>&2
  @echo *  playwright: run end-to-end tests 1>&2
@echo on
