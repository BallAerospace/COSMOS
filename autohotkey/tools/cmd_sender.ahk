SetWinDelay 1000
WinWaitActive Command Sender
Sleep 500
Click 85 100 ; Target dropdown
Sleep 500
Click 75 128 ; INST2
Sleep 500
Click 365 100 ; Command dropdown
Sleep 500
Click 365 140 ; ASCIICMD
Sleep 500
Click 600 100 ; Send
WinWaitActive Error ; Error connecting to CTS
Sleep 1000
Send {Enter}
WinWaitActive Command Sender
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Command Sender
Sleep 500
Click 60 600 ; Click in the Command History
Sleep 500
Send cmd( ; Cause a popup completion
Sleep 500
Send {Down 1}{Enter} ; INST
Sleep 500
Send {Enter} ; ABORT
Sleep 500
Send {Enter} ; Send it CMD-12, CMD-13
Sleep 500
Send ^s ; Send Raw
WinWaitActive Send Raw
Sleep 500
Click 100 105 ; Cancel
WinWaitActive Command Sender
Sleep 500
Send ^s ; Send Raw
WinWaitActive Send Raw
Sleep 500
Send {Enter}
WinWaitActive Select File
Sleep 500
Send outputs\logs\cmd.bin{Enter}
WinActivate Send Raw
Click 310 105 ; Click OK CMD-10
WinWaitActive Command Sender
Sleep 500
Click 85 100 ; Target dropdown CMD-1
Sleep 500
Click 85 115 ; INST
Sleep 500
Click 610 100 ; Send CMD-2
Sleep 500
Click 365 100 ; Command dropdown CMD-1
Sleep 500
Click 365 165 ; Collect command CMD-3
Sleep 500
Click 610 100 ; Send should fail due to TYPE required CMD-6
Sleep 500
WinWaitActive Error
Sleep 500
Send {Enter}
WinWaitActive Command Sender
Click 240 210 ; Click in the TYPE parameter CMD-5
Sleep 500
Send 5{Enter}
Sleep 500
Click 610 100 ; Send CMD-2
Sleep 500
Click 150 275 ; Click in the TEMP parameter
Sleep 500
Send 100{Enter}
Sleep 500
Click 150 210 ; Click on the TYPE parameter
Sleep 500
Click 150 210 ; Click on the TYPE parameter
Sleep 500
Click 150 225 ; Click on NORMAL CMD-4
Sleep 500
Click 610 100 ; Send should fail due to out of range
WinWaitActive Error
Sleep 500
Send {Enter}
WinWaitActive Command Sender
Sleep 500
Send !m ; Mode
Sleep 500
Send i ; Ignore Range Checks
Sleep 500
Click 610 100 ; Send should succeed
Sleep 500
Click 150 275 ; Click in the TEMP parameter
Sleep 500
Send 10{Enter} ; Set it to an allowable value
Sleep 500
Send !m ; Mode
Sleep 500
Send p ; Disable parameter conversions
Sleep 500
Click 610 100 ; Send should succeed
Sleep 500
Send !m ; Mode
Sleep 500
Send i ; Ignore Range Checks CMD-7
Sleep 500
Click 610 100 ; Send should succeed CMD-7
Sleep 500
Click 150 210 ; Click on the TYPE parameter
Sleep 500
Click 150 210 ; Click on the TYPE parameter
Sleep 500
Click 150 239 ; Click on SPECIAL CMD-4
Sleep 500
Click 610 100 ; Send
WinWaitActive Hazardous Command
Sleep 500
Click 290 110 ; Cancel CMD-11
WinWaitActive Command Sender
Sleep 500
Click 610 100 ; Send
WinWaitActive Hazardous Command
Sleep 500
Send {Enter} ; Confirm send because hazardous CMD-11
WinWaitActive Command Sender
Sleep 500
Send !m ; Mode
Sleep 500
Send d ; Display in Hex
Sleep 500
Send !m ; Mode
Sleep 500
Send s ; Show Ignored CMD-9
Sleep 500
Click 275 390 ; Click in the TYPE parameter
Sleep 500
Send 5{Enter}
Sleep 500
Click 610 100 ; Send
Sleep 500
Click right 500 390 ; Right Click in the TYPE parameter
Sleep 500
Click right 515 375 ; Details
WinWaitActive INST COLLECT
Sleep 500
Send {Enter}
WinWaitActive Command Sender
Sleep 500
Click right 200 460 ; Click in TEMP
Sleep 500
Click 215 475 ; Select File
WinWaitActive Insert
Sleep 500
Send cmd.bin{Enter}
WinWaitActive Command Sender
Sleep 500
Click 70 70 ; Search box
Send I
Sleep 100
Send N
Sleep 100
Send S
Sleep 100
Send T
Sleep 100
Send 2
Sleep 100
Send {Space}
Sleep 100
Send C
Sleep 100
Send O
Sleep 500
Send {Enter}
Sleep 500
Click 180 390 ; Click on Type
Sleep 500
Click 180 390 ; Click on Type
Sleep 500
Click 180 425 ; Click on Special
Sleep 500
Send !m ; Mode
Sleep 500
Send i ; Ignore Range Checks
Sleep 500
Send !m ; Mode
Sleep 500
Send d ; Display in Hex CMD-8
Sleep 500
Send !m ; Mode
Sleep 500
Send s ; Show Ignored
Sleep 500
Click 60 625 ; Click in the Command History
Sleep 500
Send {Down 6}{Up}{Enter}

; Shut down the CTS
WinActivate Command and Telemetry Server
WinWaitActive Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive Confirm Close
Sleep 500
Send {Enter}

WinActivate Command Sender
Send ^q
