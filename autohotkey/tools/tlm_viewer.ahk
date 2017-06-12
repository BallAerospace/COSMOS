SetWinDelay 500
SetKeyDelay 10

Sleep 500
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000

WinActivate Telemetry Viewer
Sleep 1000

Send ^g ; File->Generate Screens TV-4
WinWaitActive Select
Send {Enter}
WinWaitActive Generating
Send {Enter}
WinWaitActive Telemetry Viewer
Sleep 1000

Click 260 95 ; Edit Screen
Sleep 2000
Send !f{x}      ; Exit text editor
WinActivate Telemetry Viewer
WinWaitActive Telemetry Viewer

Click 200 95 ; Show Screen TV-1, TV-2
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 123 ; Array
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 137 ; Block
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 150 ; Commanding
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 164 ; Graphs
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 176 ; Ground
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 190 ; HS
Sleep 2000

WinActivate Command and Telemetry
Click 455 60 ; Status
Sleep 500
Click 120 115
Sleep 500
Click 120 145
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 203 ; HS
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 215 ; Other
Sleep 2000

WinActivate Telemetry Viewer
Click 100 95
Sleep 500
Click 100 228 ; Tabs
Sleep 2000

WinActivate Telemetry Viewer
Click 50 68
Sleep 500
Send t
Sleep 500
Send e
Sleep 500
Send m
Sleep 500
Send p
Sleep 500
Send 1
Sleep 500
Send {Enter}
Sleep 1000

; Save configuration TV-3
WinActivate Telemetry Viewer
Send ^s ; File->Save Config
WinWaitActive Save
Send test.txt{Enter}
WinWaitActive Telemetry Viewer

Send ^t ; Audit screens TV-5
WinWaitActive Audit
Sleep 1000
Send {Enter}
Sleep 2000 ; Wait for the editor to open
Send !f ; File
Sleep 500
Send x ; Close
WinWaitActive Telemetry Viewer

; Close down command and telemetry server
WinActivate Command and Telemetry Server
Send ^q
Sleep 500
Send {Enter}

; Quit Telemetry Viewer
WinActivate Telemetry Viewer
Send ^q
WinWaitActive Confirm
Send n
WinWaitActive Telemetry Viewer
Send ^q
WinWaitActive Confirm
Send {Enter}
Sleep 500
