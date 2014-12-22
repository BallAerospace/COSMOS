SetWinDelay 500
WinWaitActive Telemetry Grapher

; Connect to the CT server
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000
WinActivate Telemetry Grapher
Send {Enter}

Sleep 20000

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive, Confirm Close
Send {Enter}

Sleep 2000

; Quit Telemetry Grapher
WinActivate Telemetry Grapher
Send ^q

