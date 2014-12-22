WinWaitActive Command and Telemetry Server
Sleep 1000
; Targets tab
Click 110 60
Sleep 1000
; Cmd Packets tab
Click 185 60
Sleep 1000
; Tlm Packets tab
Click 270 60
Sleep 1000
; Routers tab
Click 340 60
Sleep 1000
; Logging tab
Click 400 60
Sleep 500
Click 150 115 ; Start Logging on All
Sleep 1000
Click 150 145 ; Start Telemetry Logging
Sleep 1000
Click 150 175 ; Start Command Logging
Sleep 1000
Click 465 410 ; Start Tlm Logging
Sleep 1000
Click 165 410 ; Start Cmd Logging
Sleep 1000
; Status tab
Click 460 60
Sleep 1000

Click 65 40 ; File
Sleep 500
Click 65 62
WinWaitActive About
Sleep 1000
Send pry
WinWaitActive Pry
Send ?{Enter}
Sleep 1000
Send {Esc}
WinWaitActive Command and Telemetry Server

Send ^q

