SetWinDelay 1000
SetTitleMatchMode 2 ; Contain the title anywhere to match
WinWaitActive Table Manager

; Test the File menu
Send ^n ; File -> New TBL-1
WinWaitActive Open
Send ConfigTables_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive Table Manager
Sleep 1000

Send {Tab}-1{Enter} ; Change something TBL-13

Send ^o ; File -> Open TBL-2
WinWaitActive Open
Send ConfigTables.dat{Enter}
WinWaitActive Table Manager

Send {Tab 2}1{Enter} ; Change something TBL-7, TBL-14
Send ^s ; File -> Save TBL-7
Sleep 1000

Send 2222{Enter} ; Change something
Sleep 500

Send ^o ; File -> Open
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
Click 175 120 ; Two Dimensional
Sleep 500
Send -1{Tab}-1

Send ^k ; File->Check All TBL-3
WinWaitActive Check
Send {Enter}
WinWaitActive Table Manager

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
Sleep 1000

; Test the Table menu
Click 75 120 ; One Dimensional
Sleep 500
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
}
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

Send ^o
WinWaitActive Open
Send OneDimensionalTable.dat{Enter}
WinWaitActive Table Manager

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

Send !t ; Table
Sleep 500
Send f ; Commit to existing
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Manually
Send n
WinWaitActive Table Manager

Send !t ; Table
Sleep 500
Send f ; Commit to existing TBL-11
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Manually
Send {Enter}
WinWaitActive Open
Send {Esc}

Send !t ; Table
Sleep 500
Send f ; Commit to existing TBL-11
WinWaitActive Open
Send Test.dat{Enter}
WinWaitActive Manually
Send {Enter}
WinWaitActive Open
Send ConfigTables_def.txt{Enter}

Send !t ; Table
Sleep 500
Send u ; Update definition TBL-12
WinWaitActive Update
Send {Enter}
WinWaitActive Table Manager

Click 175 120 ; Tlm Monitoring Table
Sleep 500

; Demonstrate the mouseovers
Click 80 165 0 ; Move the mouse to the values
MouseMove 700, 165, 50

Click 200 165 ; Activate the combobox
Sleep 500
Click         ; Make the dropdown appear
Sleep 500
Click 200 228 ; Choose the value
Sleep 1000

Send ^n ; File->New
WinWaitActive File New
Send n
WinWaitActive Table Manager
Send ^n ; File->New
WinWaitActive File New
Send y
WinWaitActive Open
Send TwoDimensionalTable_def.txt{Enter}
WinWaitActive Select
Send {Enter}
WinWaitActive Table Manager

; Quit Table Manager
Sleep 500
Send ^q
Sleep 500

