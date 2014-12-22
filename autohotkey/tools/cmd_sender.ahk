SetWinDelay 1000
WinWaitActive Command Sender
Sleep 2000
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000
WinActivate Command Sender
Click 60 600 ; Click in the Command History
Sleep 500
Send cmd( ; Cause a popup completion
Sleep 500
Send {Down 2}{Enter} ; INST
Sleep 500
Send {Enter} ; ABORT
Sleep 500
Send {Enter} ; Send it CMD-12, CMD-13
Sleep 500
Send ^s ; Send Raw
WinWaitActive Send Raw
Click 100 105 ; Cancel
WinWaitActive Command Sender
Send ^s ; Send Raw
WinWaitActive Send Raw
Send {Enter}
WinWaitActive Select File
Send outputs\logs\cmd.bin{Enter}
WinActivate Send Raw
Click 310 105 ; Click OK CMD-10
WinWaitActive Command Sender
Click 85 75 ; Target dropdown CMD-1
Sleep 500
Click 75 103 ; INST
Sleep 500
Click 610 75 ; Send CMD-2
Sleep 500
Click 365 75 ; Command dropdown CMD-1
Sleep 500
Click 365 140 ; Collect command CMD-3
Sleep 500
Click 610 75 ; Send should fail due to TYPE required CMD-6
Sleep 500
WinWaitActive Error
Send {Enter}
Click 240 185 ; Click in the TYPE parameter CMD-5
Send 5{Enter}
Sleep 500
Click 610 75 ; Send CMD-2
Sleep 500
Click 150 250 ; Click in the TEMP parameter
Sleep 500
Send 100{Enter}
Sleep 500
Click 150 185 ; Click on the TYPE parameter
Sleep 500
Click 150 185 ; Click on the TYPE parameter
Sleep 500
Click 150 200 ; Click on NORMAL CMD-4
Sleep 500
Click 610 75 ; Send should fail due to out of range
WinWaitActive Error
Send {Enter}
WinWaitActive Command Sender
Send !m ; Mode
Sleep 500
Send i ; Ignore Range Checks
Sleep 500
Click 610 75 ; Send should succeed
Sleep 500
Click 150 250 ; Click in the TEMP parameter
Sleep 500
Send 10{Enter} ; Set it to an allowable value
Sleep 500
Send !m ; Mode
Sleep 500
Send p ; Disable parameter conversions
Sleep 500
Click 610 75 ; Send should succeed
Sleep 500
Send !m ; Mode
Sleep 500
Send i ; Ignore Range Checks CMD-7
Sleep 500
Click 610 75 ; Send should succeed CMD-7
Sleep 500
Click 150 185 ; Click on the TYPE parameter
Sleep 500
Click 150 185 ; Click on the TYPE parameter
Sleep 500
Click 150 214 ; Click on SPECIAL CMD-4
Sleep 500
Click 610 75 ; Send
WinWaitActive Hazardous Command
Click 290 110 ; Cancel CMD-11
WinWaitActive Command Sender
Click 610 75 ; Send
WinWaitActive Hazardous Command
Send {Enter} ; Confirm send because hazardous CMD-11
WinWaitActive Command Sender
Send !m ; Mode
Sleep 500
Send d ; Display in Hex
Sleep 500
Send !m ; Mode
Sleep 500
Send s ; Show Ignored CMD-9
Sleep 500
Click 275 365 ; Click in the TYPE parameter
Sleep 500
Send 5{Enter}
Sleep 500
Click 610 75 ; Send
Sleep 500
Click right 500 365 ; Right Click in the TYPE parameter
Sleep 500
Click right 515 350 ; Details
WinWaitActive INST COLLECT
Send {Enter}
WinWaitActive Command Sender
Click right 200 435 ; Click in TEMP
Sleep 500
Click 215 450 ; Select File
WinWaitActive Insert
Send cmd.bin{Enter}
WinWaitActive Command Sender
Click 85 75 ; Target dropdown
Sleep 500
Click 75 115 ; INST2
Sleep 500
Click 365 75 ; Command dropdown
Sleep 500
Click 365 140 ; Collect command
Sleep 500
Click 180 365 ; Click on Type
Sleep 500
Click 180 365 ; Click on Type
Sleep 500
Click 180 400 ; Click on Special
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
Click 60 600 ; Click in the Command History
Sleep 500
Send {Down 6}{Up}{Enter}

; Shut down the CTS
WinActivate Command and Telemetry Server
WinWaitActive Command and Telemetry Server
Send ^q
WinWaitActive Confirm Close
Send {Enter}

WinActivate Command Sender
Send ^q
