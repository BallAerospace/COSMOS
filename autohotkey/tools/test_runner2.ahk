SetWinDelay 500

; Start the CmdTlmServer
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000

WinActivate Test Runner
WinWaitActive Test Runner
Sleep 1000
Click 530 130 ; Click Test Case
Sleep 1000
Click 530 160 ; Select Test Case
Sleep 1000
Click 530 100 ; Click Test Group
Sleep 1000
Click 530 130 ; Select Test Group
Sleep 1000
Click 530 70 ; Click Test Suite
Sleep 1000
Click 530 100 ; Select Test Suite
Sleep 1000


Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Enter
Send {Tab}1{Tab}2{Tab}e{Tab}3
Sleep 1000
Send {Enter}
WinWaitActive Test Runner
Sleep 5000
Click 760 195 ; Stop
WinWaitActive Results
Send {Enter}
Sleep 2000

; Shut down the CTS
WinActivate Command and Telemetry Server
Sleep 1000
Send ^q
WinWaitActive, Confirm Close
Sleep 500
Send {Enter}

; Shutdown Test Runner
WinActivate Test Runner
WinWaitActive Test Runner
Sleep 1000
Send ^q ; File Quit



