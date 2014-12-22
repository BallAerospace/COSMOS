WinWaitActive, Limits Monitor ahk_class QWidget
Sleep 2000
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000
WinActivate Limits Monitor
Sleep 3000
Send !fp ; Options
WinWaitActive Options
Sleep 500
Click 25 48 ; Enable colorblind mode
Sleep 500
Send {Enter}
Sleep 500

Click 400 130 ; Ignore LM-2
Sleep 500
Click 400 130 ; Ignore
Sleep 500
Click 400 130 ; Ignore
Send ^r ; Reset
Sleep 3000
Sleep 500
Click 400 130 ; Ignore
Sleep 500
Send !fv ; View Ignored
WinWaitActive Ignored
Sleep 500
Send {Enter}
Sleep 500
Send ^s ; Save Configuration LM-5
WinWaitActive Save As
Sleep 500
Send {Enter}
Sleep 500
Send !fc ; Clear Ignored
Sleep 3000
Send ^o ; Open configuration LM-6
WinWaitActive Open
Sleep 500
Send {Enter}
Sleep 1000
Click 80 60 ; Log tab LM-3
Sleep 3000
Click 35 60 ; Limits tab LM-1, LM-4
Sleep 500
Send !fp ; Options
WinWaitActive Options
Sleep 500
Click 25 48 ; Disable colorblind mode
Sleep 500
Send {Enter}

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
; Status tab
Click 460 60
Sleep 1000
Click 125 115 ; Limits Set
Sleep 500
Click 125 145 ; TVAC Set
Sleep 5000
Send ^q
WinWaitActive, Confirm Close
Send {Enter}

WinActivate Limits Monitor
Sleep 500
Send ^q

