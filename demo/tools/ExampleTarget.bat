@ECHO OFF

IF NOT EXIST %~dp0LaunchTool.bat (
  echo %~dp0LaunchTool.bat does not exist
  pause
  exit /b
)

call %~dp0LaunchTool.bat ruby.exe %~n0 %*
