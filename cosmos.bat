
if ("%1"=="") goto usage

if ("%1"=="start") goto startup

if ("%1"=="stop") goto stop

if ("%1"=="build") goto build

if ("%1"=="cleanup") goto cleanup

if ("%1"=="setup") goto setup

:setup
scripts/windows/cosmos_setup
goto :eof

:deploy
scripts/windows/cosmos_deploy
goto :eof

:cleanup
scripts/windows/cosmos_cleanup
goto :eof

:build
scripts/windows/cosmos_build
goto :eof

:stop
scripts/windows/cosmos_stop
goto :eof

:startup
scripts/windows/cosmos_minimal_start
goto :eof

:usage
@echo Usage: %0 [start, stop, build, cleanup, deploy, setup]
exit 1
