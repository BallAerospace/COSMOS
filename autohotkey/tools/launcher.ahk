WinWaitActive, Legal ; L-1, L-4, L-5
Sleep 500
Send {Enter}
WinWaitActive, Launcher
Sleep 2000
Click 50 100 ; Launch COSMOS multitool L-3
Sleep 10000
WinActivate, Command Sender
Send ^q
Sleep 500
WinActivate, Script Runner
Send ^q
Sleep 500
WinActivate, Packet Viewer
Send ^q
Sleep 500
WinActivate, Telemetry Viewer
Send ^q
Sleep 1000
Send {Enter}
Sleep 500
WinActivate, Command and Telemetry Server
Send ^q
Sleep 1000
Send {Enter}
Sleep 500
WinActivate, Launcher
Sleep 500
Click 130 100 ; Launch Command and Telemetry Server L-2
Sleep 1000
Send {Enter}
WinWaitActive, Command and Telemetry Server
Sleep 2000
Send ^q
Sleep 2000
Send {Enter}
Sleep 500
WinActivate, Launcher
Sleep 500
Send ^q

