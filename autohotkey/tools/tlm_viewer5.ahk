SetWinDelay 500
SetKeyDelay 10

Sleep 2000
Run ruby.exe %A_ScriptDir%/CmdTlmServer
WinActivate "INST ADCS"
Sleep 4000

; Close down command and telemetry server
WinActivate Command and Telemetry Server
Send ^q
Sleep 500
Send {Enter}

; Quit Telemetry Viewer
WinActivate "INST ADCS"
Sleep 500
Click 497 10 ; Close the window
Sleep 500

