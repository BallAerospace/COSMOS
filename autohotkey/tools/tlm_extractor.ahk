SetWinDelay 1000
SetTitleMatchMode 2 ; Contain the title anywhere to match
WinWaitActive Telemetry Extractor

; Start by processing the nominal scenario with some extra clicks
Sleep 500
Click 142 810   ; Click Process (Illegal, no file has been selected)
WinWaitActive Error
Send {Enter}    ; Accept and return
WinWaitActive Telemetry Extractor

Click 736 347 ; Add COSMOS target
Sleep 500
Click 648 347 ; Add Packet
Sleep 500
Click 45 267 ; Click an item
Sleep 500
Send {Down 50}{Delete} ; Remove the last item TE-11
Sleep 500
Click 45 267 ; Click an item again
Sleep 500
Send {Down 50} ; Scroll to the bottom
Sleep 100
Send +{Up 50}  ; Shift select the COSMOS target and packet
Sleep 500
Send {Delete} ; Remove them
Sleep 500

; Use the search box
Click 70 320
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
Sleep 500
Click 740 350 ; Add Target TE-4
Sleep 500
Click 640 350 ; Add Packet TE-3
Sleep 500
Click 540 350 ; Add Item TE-2
Sleep 500
Click 45 267 ; Click an item again
Sleep 500
Send ^{End} ; Scroll to the bottom
Sleep 500
Send +{Home} ; Select everything
Sleep 500
Send {Delete} ; Remove them
Sleep 500

Click 750 90    ; Click Browse
WinWaitActive Open
Send {Tab 3}{Enter} ; Click Cancel (Just to exercise this logic)
WinWaitActive Telemetry Extractor
Click 750 90    ; Click Browse (Again...) TE-10
WinWaitActive Open
Send tlm_extractor.txt{Enter} ; Load the default telem extractor text file
WinWaitActive Telemetry Extractor
Send !f         ; File
Sleep 500
Send p          ; Options
WinWaitActive Options
Sleep 500
Send {Enter}
Sleep 500
WinWaitActive Telemetry Extractor

Click 670 467    ; Click on Log Files Browse
WinWaitActive Select
Send tlm.bin{Enter} ; Enter telemetry bin filename
WinWaitActive Telemetry Extractor
Click 670 467    ; Click on Log Files Browse
WinWaitActive Select
Send bigtlm.bin{Enter} ; Enter telemetry bin filename
WinWaitActive Telemetry Extractor
Click 142 810   ; Click Process Files
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log
Click 455 307   ; Cancel
WinWaitActive Telemetry Extractor

; Add another packet so there will be common items in the shared column dialog
Click 100, 347 ; Target dropdown
Sleep 500
Click 100, 391 ; Select INST2 target
Sleep 500
Click 640 350 ; Add Packet INST2 ADCS
Sleep 500

Send ^f         ; Toggle fill down checkbox
Sleep 500
Send ^m^m       ; Check and uncheck Matlab header checkbox (we leave checked below)
Sleep 500
Send ^u         ; Check unique only
Sleep 500
Send !m         ; Mode
Sleep 500
Send a          ; Shared columns (all)
Sleep 500
Send !m         ; Mode
Sleep 500
Send s          ; Shared columns (selected)
Sleep 500
Send !m         ; Mode
Sleep 500
Send e          ; Select shared columns
WinWaitActive Select Common Items
Sleep 500
Send {Enter}    ; Cancel
WinWaitActive Telemetry Extractor
Send !m         ; Mode
Sleep 500
Send e          ; Select shared columns
WinWaitActive Select Common Items
Sleep 500
Click 88,51     ; Select TIMEFORMATTED item
Sleep 500
Click 125, 250  ; save
WinWaitActive Telemetry Extractor
Send !m         ; Mode
Sleep 500
Send c          ; Full column names
Sleep 500
Send !m         ; Mode
Sleep 500
Send n          ; Normal columns
Sleep 500
Click 180 405  ; Click in Downsample
Send +{Left 3}5.0{Enter} ; Downsample to 5 seconds
Sleep 500
Click 142 810   ; Click Process Files TE-1
WinWaitActive Warning
Send {Enter}
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log
Sleep 8000      ; Longer delay to process bin file
Send {Enter}
WinWaitActive Telemetry Extractor
Click 668 810   ; Open log in Excel for viewing TE-8
WinWaitActive Excel
Sleep 2000
Send !f{x}      ; Exit out of Excel
Sleep 500
Send n          ; In case it asks if we want to save changes
WinActivate Telemetry Extractor
WinWaitActive Telemetry Extractor
Sleep 500
Click 408 810   ; Open log in text editor TE-7
Sleep 2000
Send !f{x}      ; Exit text editor
WinWaitActive Telemetry Extractor
Sleep 500

; Exercise remaining options (even if they give 'silly' results)
Send ^f         ; Toggle back fill down checkbox
Sleep 500
Send ^m         ; Toggle on  Matlab header checkbox
Sleep 500

Click 240 378 ; Click in the Column Name
Sleep 500
Send Text{Tab}`%{Tab}
Sleep 100
Send {Space} ; Add Text TE-6
Sleep 500

Click 45 267 ; Click an item again
Sleep 500
Send {Down 50} ; Scroll to the bottom
Click right 50 284  ; Click on the Text
Sleep 500
Click 143 291
WinWaitActive Edit
Send {Tab}D`%{Enter}
WinWaitActive Telemetry Extractor

Click 530 350 ; Add a telemetry item to list
Sleep 500
Click 413 350 ; Scroll through telemetry items and pick another tlm point
Sleep 500
Send {Down 2}{Enter}
Sleep 500
Click 530 350 ; Add a telemetry item to list
sleep 500
Click 413 350 ; Scroll through telemetry items and pick another tlm point
Sleep 500
Send {Down 2}{Enter}
Sleep 500
Click 530 350 ; Add a telemetry item to list
Sleep 500

Click 45 267 ; Click an item again
Sleep 500
Send {Down 50} ; Scroll to the bottom
Click right 50 285  ; Click on the item
Sleep 500
Click 104 318 ; Delete
Sleep 500

; Modify a telemetry unit types
Click 97 133 ; Alter selected telemetry types
Sleep 500
Send {Enter}  ; Exit out no change
WinWaitActive Edit
Send {Enter}
WinWaitActive Telemetry Extractor
Click 97 133 ; Alter selected telemetry type
Sleep 500
Send {Enter}  ; Reselect item, and cancel out
WinWaitActive Edit
Send {Tab 2}{Enter}
WinWaitActive Telemetry Extractor

; Select multiple items to modify
Click 97 145
Sleep 500
Send +{Down 3}  ; Shift select three more
Sleep 500
Send ^e         ; Edit
WinWaitActive Edit
Sleep 500
Send {Down 4}
Sleep 500
Click 25 113   ; Apply to All
Sleep 500
Send {Enter}
WinWaitActive Telemetry Extractor
Send ^e        ; Edit again TE-5
WinWaitActive Edit
Sleep 500
Send {Up 3}{Enter}
Sleep 1000
Send {Up 2}{Enter}
Sleep 1000
Send {Up 1}{Enter}
Sleep 1000
Send {Enter}
WinWaitActive Telemetry Extractor
Sleep 500

; Reprocess with new selections
Click 664 464    ; Click on Browse
WinWaitActive Select
Send tlm.bin{Enter} ; Enter telemetry bin filename
WinWaitActive Telemetry Extractor
Click 750 683   ; Give this run a new output filename
WinWaitActive Select
Send tlm_updated.csv{Enter}
WinWaitActive Telemetry Extractor
Click 750 712   ; Exercise changing times through the calender menu
WinWaitActive Select
Send {Left 5}{Tab 5}{Enter}
WinWaitActive Telemetry Extractor
Click 750 741
WinWaitActive Select
Send {Left 2}{Tab 5}{Enter}
WinWaitActive Telemetry Extractor
Click 142 810   ; Process with these options
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log
Sleep 4000
Send {Enter}
WinWaitActive Telemetry Extractor
Send ^s
WinWaitActive Save ; Save configuration TE-9
Send tlm_extractor_unit_test.txt{Enter}
WinWaitActive Telemetry Extractor
Send ^s
WinWaitActive Save
Send {Enter}
WinWaitActive Confirm
Send {Tab}{Enter}
WinWaitActive Telemetry Extractor

; Test Log Analyze
Send !f{a} ; Analyze logs
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log File
Click 450 305 ; Cancel
WinWaitActive Telemetry Extractor
Send !f{a} ; Analyze logs
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log File
Sleep 4000
Send {Enter} ; Done
WinWaitActive Packet Counts
Click 265 10 ; Close packet counts window
WinWaitActive Telemetry Extractor

; Test Batch Mode
Click 665 713 ; Clear Time Start
Sleep 100
Click 665 740 ; Clear Time End
Sleep 100
Send ^b         ; Switch to Batch Mode
Click 667 96 ; Browse Config Files
WinWaitActive Select
Send tlm_extractor.txt{Enter} ; Load the default telem extractor text file
WinWaitActive Telemetry Extractor
Click 667 96 ; Browse Config Files
WinWaitActive Select
Send tlm_extractor2.txt{Enter} ; Load the default telem extractor text file
WinWaitActive Telemetry Extractor
Click 123 403 ; Click into Batch Name
Send CycleA{Enter}
Click 142 810   ; Process with these options
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Warning
Sleep 500
Send {Enter} ;
WinWaitActive Log
Sleep 4000
Send {Enter}
WinWaitActive Telemetry Extractor

; Open splash help/about screen and exit
Send !h{Enter}  ; Open the help dialog box
WinWaitActive About
Send {Enter}
WinWaitActive Telemetry Extractor
Send ^q         ; Exit tlm extractor GUI

