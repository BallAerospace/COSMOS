SetWinDelay 500
WinWaitActive Telemetry Grapher

Send !f
Sleep 500
Send l
WinWaitActive Load
Send temp1-4.txt{Enter}
WinWaitActive Telemetry Grapher
Sleep 2000 ; Allow the new configuration to be applied

; Exercise the start/pause/stop sequence when not connected
Sleep 500
Click 55 95  ; Start
Sleep 5000
Click 135 95 ; Pause
Sleep 500
Click 215 95 ; Stop
Sleep 500

; Connect to the CT server
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 2000
WinActivate Telemetry Grapher
Click 55 95  ; Start TG-3
Sleep 500

Click right 600 250 ; Add a plot to this tab TG-1, TG-6
Sleep 500
Send {Down}{Enter}
WinWaitActive Add
Send +{Tab}{Enter}
WinWaitActive Telemetry Grapher

Click right 600 250 ; Add a plot to this tab
Sleep 500
Send {Down}{Enter}
WinWaitActive Add
Send {Down} ; XY TG-2
Sleep 500
Send {Tab 3}Title{Tab}X Axis{Tab}Left Y{Tab}Right Y{Tab 6}-100{Tab}100{Tab}-100{Tab}100{Tab}10{Tab}10{Tab 2}-50{Tab}50{Enter}
WinWaitActive Telemetry Grapher
Click right 600 250 ; Add a plot to this tab
Sleep 500
Send {Down}{Enter}
WinWaitActive Add
Send {Down 2} ; Single XY TG-2
Sleep 500
Send {Tab 3}Title{Tab}X Axis{Tab}Left Y{Tab}Right Y{Enter}
WinWaitActive Telemetry Grapher
Click right 600 250 ; Add a plot to this tab
Sleep 500
Send {Down}{Enter}
WinWaitActive Add
Send {Enter}
WinWaitActive Telemetry Grapher

Click right 750 250 ; Add a data object to the XY plot
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab 2}i{Tab}h{Tab}Temp1{Tab}Temp2{Enter}
WinWaitActive Telemetry Grapher

Click right 450 550 ; Add a data object to the single XY plot
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab 2}i{Tab}h{Tab}Temp1{Tab}Temp2
Sleep 500
Click 263 252
Sleep 500
Click 263 280
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher

; Create all the different analysis types TG-14
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}s{Tab 3}r{Tab}{Space}
Sleep 1000 ; Wait for the horizontal line edit
Send +{Home}green{Tab}10{Tab}{Enter}
WinWaitActive Add
Send {Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object TG-7
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}d{Tab}4{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object TG-7
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}w{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object TG-7
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}ww{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}a{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}m{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}mm{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send {Tab}i{Tab}h{Tab}Temp1{Tab 2}rr{Tab 2}p{Enter}
WinWaitActive Telemetry Grapher
Click right 750 550 ; Add a data object to the linegraph
Sleep 500
Send {Down 4}{Enter} ; Add data object
WinWaitActive Add
Send +{Tab}{Enter} ; Cancel
WinWaitActive Telemetry Grapher

Sleep 5000 ; Let telemetry flow

; Save the configuration, delete tab, reload the saved configuration TG-17
Send ^s
WinWaitActive Save
Send testSaveConfiguration{Enter} ; Save configuration as testSaveConfiguration.txt

WinWaitActive Telemetry Grapher

; Delete all the plots from the tab
Click right 750 550 ; Delete a plot using the context window
Sleep 500
Send {Down 2}{Enter}
WinWaitActive Warning
Send {Enter} ; No don't delete
WinWaitActive Telemetry Grapher
Click right 750 550 ; Delete a plot using the context window
Sleep 500
Send {Down 2}{Enter}
WinWaitActive Warning
Send {Tab}{Enter} ; Yes Delete
WinWaitActive Telemetry Grapher
Send !p      ; Delete using the menu option
Sleep 500
Send d
Sleep 500
Send {Enter} ; Cancel
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send d
Sleep 500
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send d
Sleep 500
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send d
Sleep 500
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send d ; Delete when no plots exist
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send e ; Edit when no plots exist
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send x ; Export when no plots exist
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher
Send !d
Sleep 500
Send a ; Add data objects when no plots exist
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher

; Delete the tab itself
Send !t
Sleep 500
Send d
Sleep 500
Send {Tab}{Enter} ; Deleted the INST tab
WinWaitActive Telemetry Grapher
Sleep 1000

; Add a new tab
Send !t
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher

; Export non-existant data items
Send !d
Sleep 500
Send t ; Export all
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher
Send !d
Sleep 500
Send d ; Delete non-existant data objects
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher

; Reload the configuration TG-18
Send !f
Sleep 500
Send l
WinWaitActive Save
Send n
WinWaitActive Load
Send testSaveConfiguration.txt{Enter} ; Reload the saved configuration
WinWaitActive Telemetry Grapher

; Adding additional tabs TG-5
Send !t
Sleep 500
Send {Enter}
Sleep 1000
Send !t
Sleep 500
Send {Enter}
Sleep 1000

; Edit the third tab
Send !t
Sleep 500
Send e
WinWaitActive Edit
Sleep 1000
Send INST2{Enter}
WinWaitActive Telemetry Grapher
Sleep 1000

; Add a telemetry point with states to the plot
Click 550 70 ; Target
Send +{Home}ground{Down 2}{Enter}
Sleep 500

; Delete the middle tab
Click right 350 100
Sleep 500
Send {Down 2}{Enter}
Sleep 500
Send y
WinWaitActive Telemetry Grapher

; Add a few telemetry points to the plot TG-15
Click 700 70 ; Target
Send +{Home}inst{Down}{Up}{Enter}
Sleep 500
Send +{Home}inst{Down}{Enter}
Sleep 500
Send +{Home}inst{Down 2}{Enter}
Sleep 500

; Change some plot settings
Click 180 210 ; Refresh Rate TG-8
Sleep 500
Send {Backspace 5}1.0{Enter}
;Send 1.0{Enter}
Sleep 500
Click 180 185 ; Points Plotted TG-11
Sleep 500
Send {Backspace 5}500{Enter}
Sleep 500
Click 180 160 ; Points Saved TG-9
Sleep 500
Send {Backspace 10}20000{Enter}
Sleep 1000
Send {Tab}{Enter} ; Seconds Plotted TG-10
Sleep 500
Send {Backspace 5}50.0{Enter}
Sleep 500
Send {Enter}
Sleep 2000

; Edit the plot TG-16
Send !p
Sleep 500
Send e
WinWaitActive Edit
Send +{Tab}{Enter} ; Cancel
WinWaitActive Telemetry Grapher
Send !p
Sleep 500
Send e
WinWaitActive Edit
Send Title{Tab}X Axis{Tab}Left Y{Tab}Right Y{Tab}t{Tab}f{Tab}2{Tab}f{Tab}f{Tab}-100{Tab}100{Tab}-200{Tab}200{Tab}100{Tab}10{Tab}f{Enter}
Sleep 500

; Exercise the start/pause/stop sequence with telemetry points
Click 135 95 ; Pause
Sleep 5000
Click 55 95  ; Start
Sleep 5000
Click 215 95 ; Stop
Sleep 5000
Click 55 95  ; Start
Sleep 5000

; Change some plot settings
Click 180 210
Sleep 500
Send {Backspace 5}2.0{Enter}
Sleep 500
Click 180 185
Sleep 500
Send {Backspace 5}1000{Enter}
Sleep 500
Click 180 160
Sleep 500
Send {Backspace 10}30000{Enter}
Sleep 500
Click 180 135
Send {Backspace 5}100.0{Enter}
Sleep 500

Click 300 100 ; Tab 1
Sleep 500

; Modify data objects in the line plot
Click 450 250 ; Select the plot
Sleep 500
Click right 130 265
Sleep 500
Send {Down 5}{Enter}
WinWaitActive Export
Send testExportDataObject1{Enter} ; Export this data object
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Grapher
Sleep 5000
Click right 130 265
Sleep 500
Send {Down 7}{Enter} ; Reset this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 4}{Enter} ; Duplicate this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 2}{Enter} ; Delete this data object but cancel
Sleep 500
Send {Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 2}{Enter} ; Delete this data object (Duplicate still exists)
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 3}{Enter} ; Modify this data object
WinWaitActive Edit
Send +{Tab}{Enter} ; Cancel
WinWaitActive Telemetry Grapher
Click right 130 265
Sleep 500
Send {Down 3}{Enter} ; Modify this data object
WinWaitActive Edit
Send {Tab 5}r{Tab 3}t{Tab 3}r{Enter} ; Enable Raw Value Type and Show Limits Lines
Sleep 1000
Click down 60 317 ; Drag and drop the bottom to the top
Sleep 500
Click up 60 260
Sleep 1000

; Modify data objects in the XvsY plot
Click 750 250 ; Select the plot
Sleep 500
Click right 130 265
Sleep 500
Send {Down 5}{Enter}
WinWaitActive Export
Send testExportDataObject2{Enter} ; Export this data object
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Grapher
Click right 130 265
Sleep 500
Send {Down 7}{Enter} ; Reset this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 4}{Enter} ; Duplicate this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click 130 265
Sleep 500
Send {Backspace} ; Delete this data object
WinWaitActive Warning
Send {Enter} ; Cancel
WinWaitActive Telemetry Grapher
Click 130 265
Sleep 500
Send {Backspace} ; Delete this data object (Duplicate still exists)
WinWaitActive Warning
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher
Click right 130 265
Sleep 500
Send {Down 3}{Enter} ; Modify this data object
WinWaitActive Edit
Send red{Tab 2}a{Tab}q1{Tab}q2{Enter}
Sleep 1000

; Modify data objects in the single XvsY plot
Click 450 550 ; Select the plot
Sleep 500
Click right 130 265
Sleep 500
Send {Down 5}{Enter}
WinWaitActive Export
Send testExportDataObject3{Enter} ; Export this data object
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Grapher
Click right 130 265
Sleep 500
Send {Down 7}{Enter} ; Reset this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 4}{Enter} ; Duplicate this data object
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 2}{Enter} ; Delete this data object (Duplicate still exists)
Sleep 500
Send {Tab}{Enter}
Sleep 500
Click right 130 265
Sleep 500
Send {Down 3}{Enter} ; Modify this data object
WinWaitActive Edit
Send green{Enter}
Sleep 1000

; Test screenshots TG-12
Send !p
Sleep 500
Send s
WinWaitActive Save
Send testPlotScreenshot{Enter} ; Take a snapshot of this plot
WinWaitActive Telemetry Grapher
Sleep 5000
Send !t
Sleep 500
Send s
WinWaitActive Save
Send testTabScreenshot{Enter} ; Take a snapshot of this tab
WinWaitActive Telemetry Grapher
Sleep 2000
Send !f
Sleep 500
Send t
WinWaitActive Save
Send testFileScreenshot{Enter} ; Take a snapshot of the app
WinWaitActive Telemetry Grapher
Sleep 2000

; Test truncating data
Click 180 135
Send {Backspace 10}20{Enter}
Sleep 500
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher
Sleep 10000
; Test Plot menu items
Click 450 250 ; Select the line graph plot
Sleep 500
Send !p
Sleep 500
Send {Down 4}{Enter} ; Edit plot data items
WinWaitActive Edit
Send {Esc}
WinWaitActive Edit
Send {Esc}
WinWaitActive Edit
Send {Esc}
WinWaitActive Edit
Send {Esc}

Send !p
Sleep 500
Send {Down 6}{Enter} ; Export plot data items TG-13
WinWaitActive Export
Send testExportPlotDataObjects{Enter} ; Export all data objects
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Grapher
Sleep 10000

Send !p
Sleep 500
Send {Down 7}{Enter} ; Reset all data objects
Sleep 500
Send {Tab}{Enter}
WinWaitActive Telemetry Grapher

; Test the Tab menu items
Send !t
Sleep 500
Send x ; Export tab data items
WinWaitActive Export
Send testExportTabDataObjects{Enter} ; Export all data objects TG-13
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Grapher
Sleep 10000

Send !t
Sleep 500
Send r ; Reset tab data items
Sleep 500
Send y
WinWaitActive Telemetry Grapher

Click 350 100 ; Select Tab 2
Sleep 500
Send !d
Sleep 500
Send t ; Export all data objects
WinWaitActive Export
Send testExportAllDataObjects{Enter} ; Export all data objects
WinWaitActive Export Progress
Sleep 1000
Send {Enter}
;WinWaitActive, Export Error, , 2 ; Wait 2s for the window
;if (ErrorLevel == 0) ; if we did not time out waiting
;{
;  Send {Enter} ; Close the window
;}
WinWaitActive Telemetry Grapher
Sleep 10000
Send !d
Sleep 500
Send s ; Reset all data objects
Sleep 500
Send y
WinWaitActive Telemetry Grapher

; Access the about/help screen
Send !h{Enter}
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher

; Close down command and telemetry server
WinActivate Command and Telemetry Server
Send ^q
Sleep 500
Send {Enter}

; Process a log file TG-4
WinActivate Telemetry Grapher
Send ^o
WinWaitActive Process
Send {Enter}
WinWaitActive Select
Send bigtlm.bin{Enter}
WinWaitActive Process
Click 167 375
Sleep 500
Click 380 309 ; Cancel
WinWaitActive Telemetry Grapher
Send ^o
WinWaitActive Process
Send {Enter}
WinWaitActive Select
Send bigtlm.bin{Enter}
Sleep 500
Click 167 375
Sleep 5000

; Quit Telemetry Grapher
Send ^q
Sleep 500
Send {Enter}
WinWaitActive Telemetry Grapher
Send ^q
Sleep 500
Send y
WinWaitActive Save
Send {Enter}
Sleep 500
Send y
Sleep 500


