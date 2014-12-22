@ECHO OFF

SET RUBYEXE=rubyw.exe

SET "DESTINATION_DIR=%~dp0..\"
IF EXIST "%DESTINATION_DIR%Vendor\Ruby" GOTO DIREND
IF "%COSMOS_DIR%" == "" GOTO DIREND
SET "DESTINATION_DIR=%COSMOS_DIR%\"
:DIREND

IF NOT EXIST "%DESTINATION_DIR%Vendor\Ruby" GOTO SYSTEMRUBY

REM Save some variables we're going to change so we can restore them later
SET "COSMOS_GEM_HOME_SAVED=%GEM_HOME%"
SET "COSMOS_GEM_PATH_SAVED=%GEM_PATH%"
SET "COSMOS_GEMRC_SAVED=%GEMRC%"
SET "COSMOS_PATH_SAVED=%PATH%
SET "COSMOS_RUBYOPT_SAVED=%RUBYOPT%"
SET "COSMOS_RUBYLIB_SAVED=%RUBYLIB%"
SET "COSMOS_RI_DEVKIT_SAVED=%RI_DEVKIT%"

REM Set environmental variables

IF EXIST "%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\1.8" SET "GEM_HOME=%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\1.8"
IF EXIST "%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\1.9.1" SET "GEM_HOME=%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\1.9.1"
IF EXIST "%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\2.0.0" SET "GEM_HOME=%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\2.0.0"
SET "GEM_PATH=%GEM_HOME%"
SET "GEMRC=%DESTINATION_DIR%Vendor\Ruby\lib\ruby\gems\etc\gemrc"

REM Prepend embedded bin to PATH so we prefer those binaries
SET "RI_DEVKIT=%DESTINATION_DIR%Vendor\Devkit\"
SET "PATH=%DESTINATION_DIR%Vendor\Ruby\bin;%RI_DEVKIT%bin;%RI_DEVKIT%mingw\bin;%DESTINATION_DIR%Vendor\wkhtmltopdf;%PATH%"

REM Remove RUBYOPT and RUBYLIB, which can cause serious problems.
SET RUBYOPT=
SET RUBYLIB=

REM Run tool using Installer Ruby
ECHO Starting tool using installer ruby in %DESTINATION_DIR%
START "COSMOS" "%DESTINATION_DIR%Vendor\Ruby\bin\%RUBYEXE%" "%~dp0%~n0" %*

REM Restore some environmental variables we changed
SET "GEM_HOME=%COSMOS_GEM_HOME_SAVED%"
SET "GEM_PATH=%COSMOS_GEM_PATH_SAVED%"
SET "GEMRC=%COSMOS_GEMRC_SAVED%"
SET "PATH=%COSMOS_PATH_SAVED%"
SET "RUBYOPT=%COSMOS_RUBYOPT_SAVED%"
SET "RUBYLIB=%COSMOS_RUBYLIB_SAVED%"
SET "RI_DEVKIT=%COSMOS_RI_DEVKIT_SAVED%"

GOTO END
:SYSTEMRUBY

REM Use System Ruby and Environment
ECHO Starting tool using system ruby and environment
START "COSMOS" "%RUBYEXE%" "%~dp0%~n0" %*

GOTO END
:END
