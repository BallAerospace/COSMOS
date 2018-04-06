WinWaitActive, Config Editor
Sleep 1000

Click right 288 62 ; Right click on the tab
Sleep 500
Click 335 75 ; New window
Sleep 500
Click 335 96 ; Close window
Sleep 500
Send ^w ; Close
Sleep 500
Send ^w ; Close

Send !t ; alt T
sleep 500
Send {ENTER} ; Change file type

Send ^s ; File Save
WinWaitActive Save As
Send {Esc}
Sleep 500

Send ^n ; File New
Sleep 500
Send puts "Hello World"{ENTER}
Sleep 500
Send ^q ; Quit
WinWaitActive Save
Send {Enter} ; Cancel
WinWaitActive Config Editor
Send ^r ; Reload
WinWaitActive Discard Changes?
Send y
WinWaitActive Config Editor
Sleep 500
Send asdfasdf
Sleep 500
Send ^w ; File Close
WinWaitActive Save
Send n
WinWaitActive Config Editor

Send ^o ; File Open
WinWaitActive Select
Send +{Tab}+{Tab}{DOWN}{UP}{ENTER}
Sleep 500
Send {DOWN}{DOWN}{ENTER}
Sleep 500
Send {DOWN}{UP}{ENTER}
Sleep 500
Send target.txt{ENTER}

WinWaitActive Config Editor
Send ^w ; File Close
Sleep 500
Send ^o ; File Open
WinWaitActive, Select
Send target.txt{ENTER}
WinWaitActive Config Editor
Send ^o ; File Open
WinWaitActive, Select
Send, cmd_tlm_server.txt{ENTER}
WinWaitActive Config Editor
Send ^o ; File Open
WinWaitActive, Select
Send, target.txt{ENTER}
WinWaitActive Config Editor
Send ^o ; File Open
WinWaitActive, Select
Send +{Tab}+{Tab}{DOWN}{UP}{ENTER}
Sleep 500
Send inst_cmds.txt{ENTER}
Send ^o ; File Open
WinWaitActive, Select
Sleep 2000
Send inst_tlm.txt{ENTER}
WinWaitActive Config Editor
Sleep 1000

Send ^{Tab} ; Ctrl-Tab through the tabs
Sleep 500
Send ^{Tab}
Sleep 500
Send ^{Tab}
Sleep 500
Send ^+{Tab} ; Ctrl-Shift-Tab through the tabs
Sleep 500
Send ^+{Tab}
Sleep 500
Send ^+{Tab}
Sleep 500

Click 550 250
Sleep 500
Send ^{Home} ; Go to the first line
Sleep 1000

Click 1000 250 ; Change the target dropdown
Sleep 500
Click 1000 280
Sleep 1000
; Tab through the fields and change stuff
Send {Tab}PACKET{ENTER}
Sleep 1000
Send {Tab}{Down}
Sleep 1000

Click 390 105 ; Click on the second line
Loop 29 {
  Send {DOWN}
  Sleep 1000
}

Send ^r ; Reload
WinWaitActive Discard
Send {Enter} ; No
WinWaitActive Config Editor
Send ^r ; Reload
WinWaitActive Discard
Send +{Tab}{Enter} ; Yes
WinWaitActive Config Editor

Send ^+{Tab} ; inst_cmds.txt
Sleep 500
Click 550 250
Sleep 500
Send ^{Home} ; Go to the first line
Sleep 1000
Loop 20 {
  Send {DOWN}
  Sleep 1000
}

Send ^+{Tab} ; cmd_tlm_server.txt
Sleep 1000
Loop 5 {
  Send {DOWN}
  Sleep 1000
}

Send ^+{Tab} ; target.txt
Sleep 1000
Loop 6 {
  Send {DOWN}
  Sleep 1000
}
Click 377 377 ; Click on IGNORE_ITEM
Sleep 1000

Send !a ; alt A
sleep 500
Send c ; Create target
WinWaitActive Target
Send {Esc}

Send !a ; alt A
sleep 500
Send c ; Create target
WinWaitActive Target
Send AHK_TEST{ENTER}
Sleep 2000

Click 550 300
Sleep 500
Send ^{End}{Enter}{Enter} ; Go to end of file
Sleep 500
Click 1045 220 ; Add Keyword
Sleep 500
Send ^s ; Save

Click 1050 400 ; Click over in the help pane
Sleep 500
Send {Tab}{Tab} ; Tab over to the file browser
Sleep 500
Send {Delete}
WinWaitActive Delete
Send {Esc}
WinWaitActive Config Editor
Send {Delete}
WinWaitActive Delete
Send {Enter}
WinWaitActive Config Editor

Send {up}{up}{Delete}
WinWaitActive Delete
Send {Enter}
WinWaitActive Config Editor

Click right 120 230 ; Right click a folder in the tree
Sleep 500
Send Click 175 215
WinWaitActive Delete
Send {Enter}
WinWaitActive Config Editor
Sleep 1000

Send ^q ; Quit
