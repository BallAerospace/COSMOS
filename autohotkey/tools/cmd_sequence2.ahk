SetWinDelay 1000
WinWaitActive Command Sequence
Sleep 2000

Click 610 70 ; Click Stop
Sleep 2000
Click 80 179 ; Time field
Sleep 500
Send {Backspace 5}61{Enter}
Click 450 70 ; Click Start
WinWaitActive Save
Send {Tab 2}{Enter}
Sleep 1000

Send ^q ; Quit
WinWaitActive Warning ; Sequence is running
Send {Enter} ; No don't quit
WinWaitActive Command Sequence
Send ^q
WinWaitActive Warning
Send {Tab}{Enter} ; Yes quit
WinWaitActive Save
Send {Tab 2}{Enter} ; No don't save
