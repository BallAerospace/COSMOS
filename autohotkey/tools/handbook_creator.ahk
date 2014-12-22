SetWinDelay 1000
WinWaitActive Handbook Creator
Sleep 500
Click 55 75 ; Create HTML HC-1
WinWaitActive Done
Send {Enter}
WinWaitActive Handbook Creator
Click 55 100 ; Create PDF HC-2
WinWaitActive PDF Creation
Sleep 10000
Send {Enter}
WinWaitActive Handbook Creator
Click 55 135 ; Create both HC-3
WinWaitActive PDF Creation
Sleep 10000
Send {Enter}
WinWaitActive Handbook Creator
Click 55 165 ; Open in browser HC-4
Sleep 2000
WinActivate Handbook Creator
Sleep 500
Send ^q

