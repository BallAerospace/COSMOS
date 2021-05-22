@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

::::::::::::::::::::::::::::::::::
:: Ask for configuration dir
::::::::::::::::::::::::::::::::::

IF [%1]==[] (
  set /p COSMOS_INSTALL="Enter COSMOS Configuration Directory as an absolute path [C:\cosmos-demo]: "
  IF "!COSMOS_INSTALL!"=="" (
    set COSMOS_INSTALL=C:\cosmos-demo
  )
) else (
  set COSMOS_INSTALL=%~1
)
if "!COSMOS_INSTALL!"=="!COSMOS_INSTALL::\=!" (
  echo ERROR: Installation folder must be absolute path: "!COSMOS_INSTALL!"
  echo INSTALL FAILED
  pause
  exit /b 1
)
if not "!COSMOS_INSTALL!"=="!COSMOS_INSTALL: =!" (
  echo ERROR: Installation folder must not include spaces: "!COSMOS_INSTALL!"
  echo INSTALL FAILED
  pause
  exit /b 1
)

::::::::::::::::::::::::::::::::::
:: Create Installation Folder
::::::::::::::::::::::::::::::::::

IF EXIST !COSMOS_INSTALL! (
  echo ERROR: Installation folder already exists: "!COSMOS_INSTALL!"
  echo INSTALL FAILED
  pause
  exit /b 1
) else (
  :: Create the installation folder
  mkdir !COSMOS_INSTALL!
  if errorlevel 1 (
    echo ERROR: Failed to create directory: "!COSMOS_INSTALL!"
    echo INSTALL FAILED
    pause
    exit /b 1
  )
)

:: Copy the template to the new directory
xcopy /E /I /Y /Q /D cosmos-init\plugins\plugin-template\* "!COSMOS_INSTALL!" || EXIT /b 1
:: Set FN to the basename of the new directory
for /F %%i in ("!COSMOS_INSTALL!") do @set FN=%%~nxi
:: Rename the gemspec after the directory name
cd !COSMOS_INSTALL!
SET "specFile=%FN%.gemspec"
ren "!COSMOS_INSTALL!"\plugin-template.gemspec "%specFile%"
:: Replace TEMPLATE in the gemspec with the directory name
for /f "delims=" %%i in ('type "%specFile%" ^& break ^> "%specFile%" ') do (
  SET "line=%%i"
  setlocal enabledelayedexpansion
  >>"%specFile%" echo(!line:TEMPLATE=%FN%!
  endlocal
)
@echo on
