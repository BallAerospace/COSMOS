SetWinDelay 1000
WinWaitActive Script Runner
Sleep 1000

Send ^o ; File Open
WinWaitActive Select Script
Sleep 1000
Send script_test.rb{ENTER}
WinWaitActive Script Runner
Sleep 1000

Click 400 90 ; Start
WinWaitActive Telemetry Viewer
Sleep 6000
WinActivate Script Runner
WinWaitActive Script Runner
Sleep 6000
Click 400 90 ; Go
Sleep 500
Click 400 90 ; Go
Sleep 500
Click 400 90 ; Go
Sleep 1000
WinWaitActive Save File
Sleep 500
Send {Esc}
WinWaitActive Open File
Sleep 500
Send {Esc}
WinWaitActive Select something!!!
Sleep 500
Send {Esc}
WinWaitActive Open Directory
Sleep 500
Send {Esc}
Sleep 3000

WinActivate Telemetry Viewer
WinWaitActive Telemetry Viewer
Sleep 1000
Send ^q ; File Quit
WinWaitActive Confirm
Send {Enter}
Sleep 500

WinActivate Script Runner
WinWaitActive Script Runner
Sleep 2000
Send ^q ; File Quit
Sleep 500
