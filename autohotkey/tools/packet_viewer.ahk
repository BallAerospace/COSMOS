WinWaitActive Packet Viewer
Sleep 2000
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000
WinActivate Packet Viewer
Sleep 500

; Setup some initial viewing/polling options for telemetry
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Options
Send 2.0{Enter}  ; Set polling rate to 2.0 seconds PV-8
Sleep 500

; Inspect a few telemetry items
Click right 500, 180 ; Inspect the first telemetry item PV-4
Sleep 500
Send {Tab}{Enter}
Sleep 1000
Send {Enter}
Sleep 500
Click right 500, 205 ; Edit the next telemetry item PV-3, PV-5
Sleep 500
Send {Tab 2}{Enter}
Sleep 500
Send {Enter}
Sleep 500
Click right 500, 225 ; Graph the next telemetry item PV-6
Sleep 500
Send {Tab 3}{Enter}
WinWaitActive Telemetry Grapher
Sleep 5000
Send ^q
WinActivate Packet Viewer
Sleep 500

; Scroll through a bunch of telemetry pages
Click 450 95       ; Target: COSMOS/LIMITS_CHANGE
Sleep 500
Send {Down}{Enter} ; Target: COSMOS/VERSION
Sleep 500

; Switch target, and options, scroll through a bunch of telemetry pages
Send ^f            ; Switch to formatted telemetry display
Click 145 95
Sleep 500
Send {Down}{Enter} ; Target: INST/ADCS PV-1, PV-2
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST/HEALTH_STATUS
Sleep 500
Send ^b            ; Toggle colorblind mode PV-7, PV-9
Sleep 500
Send ^c            ; Switch to normal converted telemetry display PV-10
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST/IMAGE
Sleep 500
Send ^a            ; Switch to raw telemetry display PV-10
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST/MECH
Sleep 500
Send ^u            ; Switch to formatted telemetry with units display PV-10
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST/MECH
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST/PARAMS
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
Click 145 95
Sleep 500
Send {Down 2}{Enter} ; Target: INST2/HEALTH_STATUS
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST2/ADCS
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST2/PARAMS
Sleep 500
Click 450 95
Sleep 500
Send {Down}{Enter} ; Target: INST2/IMAGE
Sleep 500
Click 450 95
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

; Close down command and telemetry server
WinActivate Command and Telemetry Server
Sleep 500
Send ^q
Sleep 500
Send {Enter}
Sleep 500

; Cleanup and last of the options (help menu selections)
WinActivate Packet Viewer
Send ^r            ; Reset back to default
Send !h{Enter}     ; Bring up Help page
Sleep 1000
Send {Enter}
Send ^q            ; Exit packet viewer GUI

