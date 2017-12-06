SetWinDelay 500

WinWaitActive Replay
Sleep 1000

; Click on all the buttons with no file loaded
Click 75 180 ; Rewind
Sleep 500
Click 188 180 ; Go back one packet
Sleep 500
Click 300 180 ; Play backwards
Sleep 500
Click 408 180 ; Stop
Sleep 500
Click 515 180 ; Play
Sleep 500
Click 625 180 ; Advance one packet
Sleep 500
Click 737 180 ; Go to the end
Sleep 500

Click 710 115 ; Browse
WinWaitActive Select Log File
Click 370 50 ; Browse
WinWaitActive Select Log File:
Send bigtlm.bin{Enter}
Sleep 500
WinWaitActive Select Log File
Click 150 315 ; Ok
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Replay
Sleep 2000
Click 710 115 ; Browse
WinWaitActive Select Log File
Click 370 50 ; Browse
WinWaitActive Select Log File:
Send bigtlm.bin{Enter}
Sleep 500
WinWaitActive Select Log File
Click 150 315 ; Ok
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Replay
Sleep 2000

Click 515 180 ; Play RPY-1
Sleep 5000
Click 408 180 ; Stop
Sleep 500
Click 75 180 ; Rewind
Sleep 1000
Click 515 180 ; Play RPY-2
Sleep 3000
Click 408 180 ; Stop
Sleep 500
Click 300 180 ; Play backwards RPY-2
Sleep 2000
Click 408 180 ; Stop
Sleep 1000
Loop 4
{
  Click 625 180 ; Advance one packet RPY-6
  Sleep 500
}
Loop 4
{
  Click 188 180 ; Go back one packet
  Sleep 500
}
Sleep 1000
Click 737 180 ; Go to the end
Sleep 500
Click 625 180 ; Advance one packet RPY-5
Sleep 500
Click 75 180 ; Rewind
Sleep 500
Click 188 180 ; Go back one packet RPY-5
Sleep 1000

Click 100 207 ; Delay dropdown RPY-4
Sleep 500
Click 100 352
Sleep 1000
Click 515 180 ; Play
Sleep 5000
Click 408 180 ; Stop
Sleep 500
Click 75 180 ; Rewind
Sleep 500

MouseClickDrag, L, 32, 322, 750, 322, 60 ; Move the bar right RPY-7
Sleep 1000
MouseClickDrag, L, 750, 322, 15, 322, 60 ; Move the bar left

; Quit Replay
WinActivate, Replay
Sleep 1000
Send ^q
Sleep 1000
Send {Enter}
