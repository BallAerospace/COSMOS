SetWinDelay 500
Sleep 2000
WinWaitActive, Test, , 3 ; Wait 3s for the window
if (ErrorLevel == 0) ; if we did not time out waiting
{
  Send {Enter}{Esc} ; Close the window
}
WinWaitActive Error
Sleep 1000
Send {Tab}{Enter}
Sleep 1000
Send ^q

