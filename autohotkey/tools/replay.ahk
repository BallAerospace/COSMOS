SetWinDelay 500

WinWaitActive Replay
Sleep 1000

; Click on all the buttons with no file loaded
Click 75 155 ; Rewind
Sleep 500
Click 188 155 ; Go back one packet
Sleep 500
Click 300 166 ; Play backwards
Sleep 500
Click 408 155 ; Stop
Sleep 500
Click 515 155 ; Play
Sleep 500
Click 625 155 ; Advance one packet
Sleep 500
Click 737 155 ; Go to the end
Sleep 500

Click 750 95 ; Browse
WinWaitActive Select
Send bigtlm.bin{Enter}
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Analyzing
Send {Enter}
WinWaitActive Replay
Click 750 95 ; Browse
WinWaitActive Select
Send bigtlm.bin{Enter}
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Analyzing
WinWaitActive Replay
Sleep 1000

Click 515 155 ; Play RPY-1
Sleep 5000
Click 408 155 ; Stop
Sleep 500
Click 75 155 ; Rewind
Sleep 1000
Click 515 155 ; Play RPY-2
Sleep 3000
Click 408 155 ; Stop
Sleep 500
Click 300 166 ; Play backwards RPY-2
Sleep 2000
Click 408 155 ; Stop
Sleep 1000
Loop 4
{
  Click 625 155 ; Advance one packet RPY-6
  Sleep 500
}
Loop 4
{
  Click 188 155 ; Go back one packet
  Sleep 500
}
Sleep 1000
Click 737 155 ; Go to the end
Sleep 500
Click 625 155 ; Advance one packet RPY-5
Sleep 500
Click 75 155 ; Rewind
Sleep 500
Click 188 155 ; Go back one packet RPY-5
Sleep 1000

Click 100 183 ; Delay dropdown RPY-4
Sleep 500
Click 100 332
Sleep 1000
Click 515 155 ; Play
Sleep 5000
Click 408 155 ; Stop
Sleep 500
Click 75 155 ; Rewind
Sleep 500

MouseClickDrag, L, 32, 300, 800, 300, 60 ; Move the bar right RPY-7
Sleep 1000
MouseClickDrag, L, 800, 300, 15, 300, 60 ; Move the bar left

; Start CmdTlmServer RPY-3
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
Send {Enter}

; Quit Replay
WinActivate, Replay
Sleep 1000
Send ^q
Sleep 500

