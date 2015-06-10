@ECHO OFF

IF NOT EXIST tools\LaunchTool.bat (
  echo tools\LaunchTool.bat does not exist
  pause
  exit /b
)

call tools\LaunchTool.bat rubyw.exe %~n0 %*
