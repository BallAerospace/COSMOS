WinWaitActive, Data Viewer ahk_class QWidget
Sleep 500
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Data Viewer
Sleep 500
Send ^r ; Reset
Sleep 500
Click 560 70 ; Stop
Sleep 500
Click 400 70 ; Start DV-1
Sleep 500
Click 480 70 ; Pause
Sleep 500
Click 400 70 ; Start
Sleep 500
Click 130 100 ; ADCS tab DV-3, DV-4
Sleep 500
Click 205 100 ; Other Packets tab DV-4
Sleep 500
Click 60 40 ; Tab tab
Sleep 500
Click 55 95 ; Disable INST PARAMS DV-6
Sleep 2000
Click right 200 100
Sleep 500
Click 215 165 ; Disable INST IMAGE
Sleep 500
Click right 200 100
Sleep 500
Click 215 142 ; Enable INST PARAMS DV-6
Sleep 2000
Click 60 40 ; Tab tab
Sleep 500
Click 60 65 ; Delete Tab
WinWaitActive, Warning
Sleep 500
Click 270 100 ; No
Sleep 500
WinActivate Data Viewer
Sleep 500
Click 60 40 ; Tab tab
Sleep 500
Click 60 65 ; Delete Tab
WinWaitActive, Warning
Sleep 500
Click 190 100 ; Yes DV-5
Sleep 500

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive, Confirm Close
Sleep 500
Send {Enter}

WinActivate, Data Viewer
Sleep 3000
Send ^o ; Open log
WinWaitActive, Open Log File
Sleep 500
Click 475 375 ; Cancel
Sleep 500
WinActivate, Data Viewer
Sleep 500
Send ^o ; Open log
WinWaitActive, Open Log File ; DV-2
Sleep 500
Send {Enter}
WinWaitActive, Select Log File
Sleep 500
Send tlm.bin{Enter}
Sleep 500
WinActivate, Open Log File
Sleep 500
Click 168 375 ; OK
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive, Processing Log File
Sleep 500
Click 380 280 ; Cancel
WinActivate Data Viewer
Sleep 500
Send ^o ; Open log
WinWaitActive, Open Log File
Sleep 500
Send {Enter}
WinWaitActive, Select Log File
Sleep 500
Send tlm.bin{Enter}
Sleep 500
WinActivate, Open Log File
Sleep 500
Click 168 375 ; OK
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive, Processing Log File
Sleep 3000
Click 140 280 ; Done
Sleep 500
WinActivate Data Viewer
Sleep 500
Click 305, 775 ; Save Text to File
WinWaitActive, Save As
Sleep 500
Send {Enter}
Sleep 500
WinActivate Data Viewer
Sleep 500
Click 305, 775 ; Save Text to File
WinWaitActive, Save As
Sleep 500
Send {Tab 4}{Enter} ; Cancel
Sleep 500
WinActivate Data Viewer
Sleep 500
Click 400 70 ; Start
Sleep 1000
Click right 130 100 ; ADCS tab
Sleep 500
Click 145 113 ; Delete tab
Sleep 500
WinWaitActive, Warning
Sleep 500
Click 190 100 ; Yes
Sleep 500
Send !td
WinWaitActive, Warning
Sleep 500
Send y
Sleep 500
Send !td
WinWaitActive, Info
Sleep 500
Send {Enter}
Sleep 500
Send ^q
