SetWinDelay 1000
WinWaitActive Command Sequence
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Command Sequence

Send ^o ; Open
WinWaitActive Select
Send bad_sequence.txt{Enter}
WinWaitActive Error
Send {Enter}
WinWaitActive Command Sequence

Send ^o ; Open
WinWaitActive Select
Send bad_sequence2.txt{Enter}
WinWaitActive Error
Send {Enter}
WinWaitActive Command Sequence

Send ^o ; Open
WinWaitActive Select
Send saved_sequence.txt{Enter}
WinWaitActive Command Sequence

Send !f ; File menu
Sleep 500
Send a ; Save As
WinWaitActive Save
Send test_sequence.txt{Enter}
WinWaitActive Command Sequence

Send !a ; Actions menu
Sleep 500
Send e ; Expand All
Sleep 1000
Send !a ; Actions menu
Sleep 500
Send d ; Display state values in hex
Sleep 1000
Send !a ; Actions menu
Sleep 500
Send s ; Show ignored items
Sleep 1000
Send !a ; Actions menu
Sleep 500
Send c ; Collapse all
Sleep 1000
Click 300 210 ; Click on sequence item to display it
Sleep 1000
Send !a ; Actions menu
Sleep 500
Send d ; Display state values in hex
Sleep 500
Send !a ; Actions menu
Sleep 500
Send s ; Show ignored items
Sleep 500

Click right 170 309 ; Right click collect type
Sleep 500
Send {Tab}{Enter}
WinWaitActive INST
Sleep 500
Send {Enter}
WinWaitActive Command Sequence

Click right 170 309 ; Right click collect type
Sleep 500
Send {Tab 2}{Enter} ; Insert filename
WinWaitActive Insert
Sleep 500
Send {Esc}
WinWaitActive Command Sequence

Click 260 311 2 ; Double click the collect type manual entry
Sleep 500
Send 9{Enter}
Sleep 500

Click 170 309 2 ; Double click the collect Type
Sleep 500
Click ; Click again to activate the drop down
Sleep 500
Send {Up}{Enter} ; Choose SPECIAL collect
Sleep 1000

Send ^t ; Disconnect mode
WinWaitActive Disconnect
Send +{Tab}{Enter} ; Cancel
WinWaitActive Command Sequence

Send ^t ; Disconnect mode
WinWaitActive Disconnect
Click 253 195 ; Select
WinWaitActive Select
Send cmd_tlm_server.txt{Enter}
WinWaitActive Disconnect
Send {Tab}{Enter} ; Confirm dialog
WinWaitActive Command Sequence

Click 450 70 ; Start
WinWaitActive Save
Send {Tab 2}{Enter} ; No
; Script should execute and complete
WinWaitActive Command Sequence

Send ^t ; Toggle off disconnect mode
WinWaitActive Disconnect
Click 253 73 ; Clear All
Send {Tab}{Enter} ; Confirm dialog
WinWaitActive Command Sequence

Send ^n ; New sequence
WinWaitActive Save
Send {Tab}{Enter} ; Yes
WinWaitActive Command Sequence

Click 100 100 ; Click the Target dropdown
Sleep 500
Send {Down}{Enter} ; Change the target
Sleep 500
Click 610 100 ; Add Abort command
Sleep 500
Click 633 155 ; Delete the command
Sleep 500
Click 610 100 ; Add Abort command
Sleep 500
Click 610 100 ; Add Abort command
Sleep 500
Click 450 100 ; Click the command dropdown
Sleep 500
Send {Down 2}{Enter} ; ASCIICMD
Sleep 500
Click 610 100 ; Add ASCIICMD
Sleep 500
Click 300 210 ; Click on the ASCIICMD to expand it
Sleep 500

Click 170 330 2 ; Click in the BINARY field
Send testtest{Enter}
WinWaitActive Error
Send {Enter}
WinWaitActive Command Sequence

Click 170 330 2 ; Double click in the BINARY field
Sleep 500
Send test{Enter}
Sleep 500

Click 170 330 2 ; Double click in the BINARY field
Sleep 500
Send 0xDEADBEEF{Enter}
Sleep 500

Click 450 70 ; Click Start
WinWaitActive Save
Send {Enter} ; Cancel
WinWaitActive Command Sequence

Click 450 70 ; Click Start
WinWaitActive Save
Send {Tab 2}{Enter} ; No
; Script should execute and complete

Click 80 155 ; First command Time field
Sleep 500
Send {Backspace 5}2.5{Enter} ; 2.5s delay
Click right 85 180
WinWaitActive Select
Send {Esc} ; Cancel absolute time select
WinWaitActive Command Sequence
Click right 80 180
WinWaitActive Select
Min := 1 + A_Min ; One minute in the future
Send {Tab 2}%Min%{Enter} ; Set the future time
WinWaitActive Command Sequence
Click right 80 210
WinWaitActive Select
Send {Tab 5}{Enter} ; Select time now
WinWaitActive Command Sequence

Send ^s ; Save
WinWaitActive Save
Send {Enter}
Sleep 500
; If the file already exists a dialog comes up
; so we tab enter to switch from default No to Yes
Send {Tab}{Enter}
WinWaitActive Command Sequence

Click 450 70 ; Click Start
Sleep 65000 ; Allow the minute to go by and the sequence to complete

Click 450 70 ; Click Start
Sleep 1000
Click 530 70 ; Click Pause
Sleep 2000
Click 450 70 ; Click Start
Sleep 2000
Click 450 70 ; Click Go and the sequence should complete
Sleep 1000

Click 450 70 ; Click Start
Sleep 1000
Click 610 70 ; Click Stop
Sleep 2000

; Shut down the CTS
WinActivate Command and Telemetry Server
WinWaitActive Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive Confirm Close
Sleep 500
Send {Enter}

WinActivate Command Sequence
Send ^q
