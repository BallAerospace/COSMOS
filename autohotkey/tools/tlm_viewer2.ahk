SetWinDelay 500
SetKeyDelay 10

Sleep 1000
WinActivate Screen
Sleep 2000
Send {Tab}
Sleep 500
Send {Enter}

Sleep 500
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
Run ruby.exe %A_ScriptDir%/ScriptRunner -w 600 -t 600

WinWaitActive Script
Send display("INST ADCS"){Enter}
Send wait 2{Enter}
Send clear("INST ADCS"){Enter}
Sleep 500
Click 400 90

; Allow the script time to run
Sleep 5000

WinActivate Script
Send ^q
Sleep 500
Send n

; Close down command and telemetry server
WinActivate Command and Telemetry Server
Send ^q
Sleep 500
Send {Enter}

; Quit Telemetry Viewer
WinActivate Telemetry
Sleep 500
Send ^q
Sleep 500
Send y

; Quit Telemetry Viewer
WinActivate Telemetry
Sleep 500
Send ^q
Sleep 500
Send y
