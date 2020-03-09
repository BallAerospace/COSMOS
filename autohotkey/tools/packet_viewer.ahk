SetWinDelay 500
SetTitleMatchMode 2 ; Contain the title anywhere to match
WinWaitActive Packet Viewer
Sleep 500
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Packet Viewer
WinWaitActive Packet Viewer
Sleep 500

; Edit the packet definition
Send !f ; File
Sleep 500
Send e ; Edit
Sleep 5000
WinWaitActive Config Editor
Send !f{x} ; Exit config editor
WinWaitActive Packet Viewer
Sleep 500

; Setup some initial viewing/polling options for telemetry
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Options
Send 2.0{Enter}  ; Set polling rate to 2.0 seconds PV-8
WinWaitActive Packet Viewer
Sleep 500

; Inspect a few telemetry items
Click right 500, 180 ; Inspect the first telemetry item PV-4
Sleep 1000
Send {Tab}{Enter}
WinWaitActive Details
Sleep 1000
Send {Enter}
WinWaitActive Packet Viewer
Sleep 500

Click right 500, 205 ; Edit the next telemetry item PV-3, PV-5
Sleep 1000
Send {Tab 2}{Enter}
WinWaitActive Edit
Sleep 1000
Send {Enter}
WinWaitActive Packet Viewer
Sleep 500

Click right 500, 225 ; Graph the next telemetry item PV-6
Sleep 1000
Send {Tab 3}{Enter}
WinWaitActive Telemetry Grapher
Sleep 5000
Send ^q
WinActivate Packet Viewer
Sleep 500

; Switch target, and options, scroll through a bunch of telemetry pages
Send ^f            ; Switch to formatted telemetry display
Sleep 500
Send ^b            ; Toggle colorblind mode PV-7, PV-9
Sleep 1000
Send !v            ; Switch to normal converted telemetry display PV-10
Sleep 500
Send c
Sleep 1000
Send ^h            ; Hide ignored items
Sleep 2000
Send ^h            ; Show ignored items
Sleep 1000
Send ^d            ; Show derived items last
Sleep 2000
Send ^d            ; Show derived items first
Sleep 1000
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST/ADCS
Sleep 500
Send !v            ; Switch to raw telemetry display PV-10
Sleep 500
Send r
Sleep 1000

Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST/PARAMS
Sleep 500
Send !v            ; Switch to formatted telemetry with units display PV-10
Sleep 500
Send u
Sleep 1000

Send !v            ; Switch to formatted telemetry display PV-10
Sleep 500
Send f
Sleep 1000

Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST/IMAGE
Sleep 500
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST/MECH
Sleep 500

; Reset to last of the options we haven't touched, and go through
; one last set of telemetry screens
Send ^r            ; Reset the GUI to default
Sleep 500
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Options
Send 1.0{Enter}
Sleep 500

; Go through the last page of telemetry screens
Send !t            ; Select Target drop down
Sleep 500
Send {Down}{Enter} ; Target: INST2/HEALTH_STATUS
Sleep 500
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST2/ADCS
Sleep 500
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST2/PARAMS
Sleep 500
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST2/IMAGE
Sleep 500
Send !p            ; Select the Packet drop down
Sleep 500
Send {Down}{Enter} ; Target: INST2/MECH
Sleep 500

; Used the lookup search box PV-11
Click 70 70
Sleep 500
Send t
Sleep 500
Send e
Sleep 500
Send m
Sleep 500
Send p
Sleep 500
Send 1
Sleep 500
Send {Enter}
Sleep 2000

Click right 380, 734 ; TEMP1 details
Sleep 1000
Send {Tab}{Enter}
WinWaitActive TEMP1
Sleep 1000
; Leave this window open because we use it later

WinActivate Packet Viewer
WinWaitActive Packet Viewer
Click right 380, 757 ; TEMP2 details
Sleep 1000
Send {Tab}{Enter}
WinWaitActive TEMP2
Sleep 1000
Send {Enter} ; Close the window

WinActivate Packet Viewer
WinWaitActive Packet Viewer
Click 250 70
Sleep 500
Send {Backspace 5}
Sleep 500
Send COLLECT_TYPE{Enter}
Sleep 1000
Click right 380, 730 ; ARY details
Sleep 1000
Send {Tab}{Enter}
WinActivate ARY
WinWaitActive ARY
Sleep 1000
Send {Enter} ; Close the window

WinActivate TEMP1
WinWaitActive TEMP1
Sleep 2000

Run ruby.exe %A_ScriptDir%/ScriptRunner -w 600 -t 600
Sleep 2000
WinActivate Script Runner
Sleep 2000
Send set_limits("INST","HEALTH_STATUS","TEMP1",-110,-105,105,110,-100,100){ENTER}
Send set_limits_set("CUSTOM"){ENTER}
Sleep 1000
Click 400, 88 ; Start

WinActivate TEMP1
WinWaitActive TEMP1
Sleep 3000

WinActivate Script Runner
WinWaitActive Script Runner
Send ^q
WinWaitActive Save
Send n

; Close down command and telemetry server
WinActivate Command and Telemetry Server
WinWaitActive Command and Telemetry Server
Send ^q
Sleep 500
Send {Enter}

; Cleanup and last of the options (help menu selections)
WinActivate Packet Viewer
Send ^r            ; Reset back to default
Send !h{Enter}     ; Bring up Help page
Sleep 1000
Send {Enter}
Send ^q            ; Exit packet viewer GUI
