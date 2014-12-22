SetWinDelay 500
WinWaitActive Script Runner

Send ^o ; File Open
WinWaitActive Select Script
Send script_test.rb{ENTER}
WinWaitActive Script Runner

Click 400 90 ; Start
WinWaitActive Telemetry Viewer
Sleep 6000
WinActivate Script Runner
Sleep 6000
Click 400 90 ; Go
Sleep 500
Click 400 90 ; Go
Sleep 500
Click 400 90 ; Go
Sleep 3000

WinActivate Telemetry Viewer
Sleep 500
Send ^q ; File Quit
WinWaitActive Confirm
Send {Enter}

WinActivate Script Runner
Sleep 500
Send ^q ; File Quit
Sleep 500

