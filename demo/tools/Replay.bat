@ECHO OFF

IF NOT EXIST LaunchTool.bat (
  echo LaunchTool.bat does not exist
  pause
  exit /b
)

call LaunchTool.bat rubyw.exe %~n0 %*
