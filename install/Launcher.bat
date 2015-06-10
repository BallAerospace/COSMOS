@ECHO OFF

IF NOT EXIST %~dp0tools\LaunchTool.bat (
  echo %~dp0tools\LaunchTool.bat does not exist
  pause
  exit /b
)

call %~dp0tools\LaunchTool.bat rubyw.exe %~n0 %*
