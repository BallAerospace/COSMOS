WinWaitActive, Command and Telemetry Server ahk_class QWidget
Sleep 1000
; Interfaces tab CTS-19, CTS-23, CTS-25
Click 160 120 ; Disconnect CTS-1, CTS-2,
Sleep 2000
Click 160 120 ; Connect CTS-2
Sleep 2000
Click 60 40 ; Edit
Sleep 500
Click 60 65 ; Clear Counters CTS-17
Sleep 500
Click 100 40 ; Help
Sleep 500
Click 100 65 ; About
WinWaitActive About
Send {Enter}

; Targets tab CTS-4, CTS-24
Click 110 60
Sleep 1000
; Cmd Packets tab CTS-5
Click 185 60
Sleep 500
Click 310 120 ; View Raw CTS-6
Sleep 500
Send {Enter} ; Pause
Sleep 500
Send {Enter} ; Resume
Sleep 500
Send {Escape} ; Close window
Sleep 500
; Tlm Packets tab CTS-7
Click 270 60
Sleep 500
Click 315 115 ; View Raw CTS-8
Sleep 500
Send {Enter} ; Pause
Sleep 500
Send {Enter} ; Resume
Sleep 500
Send {Escape} ; Close window
Sleep 500
Click 415 115 ; View in Packet Viewer CTS-18
Sleep 500
WinWaitActive Packet Viewer
Sleep 500
Send ^q
WinActivate Command and Telemetry Server
; Routers tab CTS-9
Click 340 60
Sleep 500
Click 215 120 ; Disconnect CTS-10
Sleep 1000
Click 215 120 ; Connect
Sleep 1000
; Logging tab CTS-12
Click 400 60
Sleep 500
Click 400 115 ; Stop Logging on All CTS-13
Sleep 1000
Click 150 115 ; Start Logging on All CTS-13
Sleep 1000
Click 400 145 ; Stop Telemetry Logging CTS-13
Sleep 1000
Click 150 145 ; Start Telemetry Logging CTS-13
Sleep 1000
Click 400 175 ; Stop Command Logging CTS-13
Sleep 1000
Click 150 175 ; Start Command Logging CTS-13
Sleep 1000
Click 365 410 ; Stop Cmd Logging CTS-13
Sleep 1000
Click 465 410 ; Stop Tlm Logging CTS-13
Sleep 1000
Click 165 410 ; Start Cmd Logging CTS-13
Sleep 1000
Click 265 410 ; Start Tlm Logging CTS-13
Sleep 1000
; Status tab
Click 460 60
Sleep 500
Click 115 115 ; Limits set
Sleep 500
Click 115 145 ; TVAC CTS-15

Send ^q
Sleep 500
Send {Enter}

