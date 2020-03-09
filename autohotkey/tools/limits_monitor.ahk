SetWinDelay 1000
WinWaitActive Limits Monitor
Sleep 500
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Limits Monitor
Sleep 3000
Send !fp ; Options
WinWaitActive Options
Click 25 48 ; Enable colorblind mode
Sleep 500
Send {Enter}

; Change a limits item
Run ruby.exe %A_ScriptDir%/ScriptRunner -w 800 -t 200
Sleep 2000
WinActivate, Script Runner
Sleep 2000
Send set_limits("INST", "HEALTH_STATUS", "TEMP1", -100, -80, 80, 100, -60, 60, :DEFAULT){Enter}
Send set_limits("INST", "HEALTH_STATUS", "TEMP3", -100, -80, 80, 100, -60, 60, :DEFAULT)
Sleep 1000
Click 600, 90 ; Start
WinActivate, Limits Monitor
Sleep 3000
Click 80 60 ; Log tab LM-3
Sleep 2000
Click 35 60 ; Limits tab LM-1, LM-4
Sleep 500
WinActivate Script Runner
Sleep 500
Send ^q
WinWaitActive Save
Send n

; Ignore limits items
WinWaitActive Limits Monitor
Sleep 500
Click 500 130 ; Ignore item
Sleep 500
Click 500 130 ; Ignore item
Sleep 500
Click 590 130 ; Ignore stale
Sleep 500
Click 590 130 ; Ignore stale
Sleep 500
Click 590 130 ; Ignore packet
Send ^r ; Reset
Sleep 3000
Sleep 500
Click 500 130 ; Ignore item
Sleep 500
Send ^e ; Edit Ignored
WinWaitActive Ignored
Sleep 1000
Send {Enter}

; Save the limits configuration
WinWaitActive Limits Monitor
Send ^s ; Save Configuration LM-5
WinWaitActive Save As
Send {Enter}

; Edit the ignored limits items
WinWaitActive Limits Monitor
Send ^e ; Edit Ignored
WinWaitActive Ignored
Send {Delete}
Sleep 1000
Send {Delete}
Sleep 1000
Send ^a
Sleep 500
Send {Delete}
Sleep 500
Send {Enter}
Sleep 2000

; Open the limits configuration
WinWaitActive Limits Monitor
Send ^o ; Open configuration LM-6
WinWaitActive Open
Send {Enter}

; Display the limits tab
WinWaitActive Limits Monitor
Click 80 60 ; Log tab LM-3
Sleep 3000
Click 35 60 ; Limits tab LM-1, LM-4
Sleep 500
Send !fp ; Options
WinWaitActive Options
Click 25 48 ; Disable colorblind mode
Sleep 500
Send {Enter}

; Change the Limits set
WinActivate, Command and Telemetry Server
Sleep 500
; Status tab
Click 460 60
Sleep 1000
Click 125 115 ; Limits Set
Sleep 500
Click 125 145 ; TVAC Set
Sleep 1000
WinActivate Limits Monitor
Click 80 60 ; Log tab LM-3
Sleep 2000
Click 35 60 ; Limits tab LM-1, LM-4
Sleep 500

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive Confirm Close
Send {Enter}

WinActivate Limits Monitor
Sleep 500
Send ^q
