SetWinDelay 1000
SetTitleMatchMode 2 ; Contain the title anywhere to match
WinWaitActive Table Manager

; Test the File New menu
Send ^n ; File -> New TBL-1
WinWaitActive Open
Send OldOneDimensionalTable_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive File New Errors
Send {Enter}
WinWaitActive Table Manager
Sleep 1000

Send ^n ; File->New
WinWaitActive Open
Send TwoDimensionalTable_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive Table Manager

Send !f ; File
Sleep 500
Send a ; Save As
WinWaitActive File Save
Send TwoTable.dat{Enter}
WinWaitActive Table Manager

Send ^n ; File -> New TBL-1
WinWaitActive Open
Send ConfigTables_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive Table Manager
Sleep 1000

Send ^n ; File -> New TBL-1
WinWaitActive Open
Send ConfigTables_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive File New ; File exists dialog
Send {Enter} ; Overwrite
WinWaitActive Table Manager
Sleep 1000

Send {Tab}-1{Enter} ; Change something TBL-13

Send ^o ; File -> Open TBL-2
WinWaitActive Table Modified
Send {Enter} ; No
Send ^o ; File -> Open TBL-2
WinWaitActive Table Modified
Send {Tab}{Enter} ; Yes
WinWaitActive Open
Send TwoTable.dat{Enter}
WinWaitActive Open
Send OneDimensionalTable_def.txt{Enter}
WinWaitActive Open Error
Send {Enter}
WinWaitActive Table Manager

Send !f ; File
Sleep 500
Send b ; Open Both
WinWaitActive Open
Send TwoTable.dat{Enter}
WinWaitActive Open
Send ConfigTables_def.txt{Enter}
WinWaitActive Open Error
Send {Enter}
WinWaitActive Table Manager

Send ^o ; File -> Open TBL-2
WinWaitActive Open
Send ConfigTables.dat{Enter}
WinWaitActive Table Manager

Send {Tab 2}1{Enter} ; Change something TBL-7, TBL-14
Send ^s ; File -> Save TBL-7
Sleep 2000
Send {Tab 2}abc{Enter} ; Change something TBL-7, TBL-14
Send ^s ; File -> Save TBL-7
WinWaitActive File Check
Send {Enter}
Sleep 1000

Send ^o ; File -> Open
WinWaitActive Table Modified
Send {Tab}{Enter} ; Yes
WinWaitActive Open
Send ConfigTables.dat{Enter}
WinWaitActive Table Manager

Send !f ; File
Sleep 500
Send a ; Save As
WinWaitActive File Save
Send Test.dat{Enter}
WinWaitActive Table Manager

Send ^k ; File->Check All TBL-3
WinWaitActive Check
Send {Enter}
WinWaitActive Table Manager

; Mess up some tables
Send {Tab}-1{Tab}-1{Tab}-1
Click 220 120 ; Two Dimensional
Sleep 500
Send -1{Tab}-1

; Demonstrate the mouseovers
Click 40 165 0 ; Move the mouse to the values
MouseMove 700, 165, 50

Click right 80 165
Sleep 500
Click 125 150
WinWaitActive Details
Sleep 1000
Send {Enter}
WinWaitActive Table Manager

Click 200 165 ; Activate the combobox
Sleep 500
Click         ; Make the dropdown appear
Sleep 500
Click 200 228 ; Choose the value
Sleep 1000

Send ^k ; File->Check All TBL-3
WinWaitActive File Check
Send {Enter}
WinWaitActive Table Manager

Send ^d ; Table->Default TBL-6
Click 90 120 ; One Dimensional
Send ^d ; Table->Default TBL-6
Sleep 1000

Send ^h ; File->Hex dump TBL-4
WinWaitActive Hex Dump
Click 200 200
Click WheelDown 50
Sleep 500
Click WheelDown 50
Sleep 500
Click WheelDown 50
Sleep 1000
Send {Enter}
WinWaitActive Table Manager

Send ^r ; File->Create Report TBL-5
WinWaitActive File Report
Send {Enter}

; Test the Table menu
Send !t
Sleep 500
Send c ; Table->Check TBL-8
WinWaitActive Check
Send {Enter}
WinWaitActive Table Manager

; Mess up the table
Loop 4
{
  Send {Tab}-1
}
Sleep 500
Send !t
Sleep 500
Send c ; Table->Check TBL-8
WinWaitActive Check
Send {Enter}
WinWaitActive Table Manager

Loop 4
{
  Send {Tab}1
  Sleep 200
}

; Demonstrate the mouseovers
Click 200 160 0 ; Move the mouse to the values
MouseMove 200, 440, 50

Sleep 500
Click 200 370 ; Activate the combobox
Sleep 500
Click         ; Make the dropdown appear
Sleep 500
Click 200 390 ; Choose the value
Sleep 500
Click 180 415 ; Uncheck the checkbox
Sleep 500

; Demonstrate the context menu
Click right 200 165
Sleep 500
Click 220 160
WinWaitActive Details
Sleep 1000
Send {Enter}
WinWaitActive Table Manager

Send 1{Enter}
Sleep 500
Click right 200 165
Sleep 500
Click 245 177
Sleep 500

Send !t
Sleep 500
Send d ; Table->Default TBL-6
Sleep 500

Send !t ; Table
Sleep 500
Send h ; Hex dump TBL-9
WinWaitActive Hex Dump
Send {Enter}
WinWaitActive Table Manager

Send !t ; Table
Sleep 500
Send s ; Save binary TBL-10
WinWaitActive File Save
Send {Enter}
WinWaitActive Table Manager

Click 220 120 ; Two Dimensional
Sleep 500

Send !t ; Table
Sleep 500
Send h ; Hex dump TBL-9
WinWaitActive Hex Dump
Send {Enter}
WinWaitActive Table Manager

Send ^o
WinWaitActive Table Modified
Send {Tab}{Enter} ; Yes
WinWaitActive Open
Send TwoDimensionalTable.dat{Enter}
WinWaitActive Table Manager

Send !t ; Table
Sleep 500
Send f ; Commit to existing
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Open
Send {Esc}
WinWaitActive Table Manager

Send !t ; Table
Sleep 500
Send f ; Commit to existing TBL-11
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Open
Send {Enter}
WinWaitActive Open
Send {Esc}

Send !t ; Table
Sleep 500
Send f ; Commit to existing TBL-11
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Open
Send ConfigTables_def.txt{Enter}
WinWaitActive Table Manager

; Quit Table Manager
Send {Tab}-1{Tab}-1{Tab}-1
Sleep 500
Send ^q
WinWaitActive Table Modified
Send n
WinWaitActive Table Manager
Send ^q
WinWaitActive Table Modified
Send y
Sleep 500

