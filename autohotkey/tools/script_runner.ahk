SetWinDelay 500
WinWaitActive Script Runner
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Script Runner Options
Send {Tab 3} ; Tab to Cancel
Sleep 500
Send {Enter} ; Cancel
Sleep 500
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Script Runner Options
Send {Del 4}2{Enter} ; Delay SR-25
Sleep 500
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Script Runner Options
Send {Del 4}0{Enter}
Sleep 500

Send ^s ; File Save SR-1
WinWaitActive Save As
Send {Esc}
Sleep 500

Send ^n ; File New SR-1
Sleep 500
Send puts "Hello World"{ENTER} ; SR-10
Send cmd({ENTER}{ENTER}{ENTER}{Esc}{ENTER} ; SR-3, SR-9
Send cmd({ENTER}{ENTER}{ENTER}{Esc}{ENTER} ; SR-3
Send tlm({ENTER}{ENTER}{ENTER}{Esc}{ENTER} ; SR-3
Send wait_check({ENTER}{ENTER}{ENTER}{Esc}{Left 2} == 5{Right 1}, 1{Right 1}{ENTER} ; SR-3, SR-11
Send check_expression("true == true"){ENTER} ; SR-13
Send check_expression("true == false") ; SR-12, SR-13
Send ^t ; Toggle Disconnect SR-20
WinWaitActive Disconnect
Send {Enter}
WinWaitActive Script Runner
Sleep 1000
Click 400 90 ; Start
Sleep 2000
Send ^t ; Toggle Disconnect SR-20
WinWaitActive Disconnect
Click 253 73 ; Clear All
Send {Tab}{Enter} ; Confirm dialog
WinWaitActive Script Runner
Click 400 190 ; Back into text
Sleep 500
Send ^q ; Quit
WinWaitActive Save
Send {Enter} ; Cancel
WinWaitActive Script Runner
Send ^r ; Reload
WinWaitActive Discard Changes?
Send y
WinWaitActive Script Runner
Sleep 500
Send asdfasdf
Sleep 500
Send ^w ; File Close
WinWaitActive Save
Send n
WinWaitActive Script Runner

Send ^o ; File Open SR-1
WinWaitActive Select Script
Send collect.rb{ENTER}
WinWaitActive Script Runner
Send ^w ; File Close SR-1
Sleep 500
Send ^o ; File Open
WinWaitActive, Select Script
Send collect.rb{ENTER}
WinWaitActive Script Runner
Send ^o ; File Open
WinWaitActive, Select Script
Send, collect_util.rb{ENTER}
WinWaitActive Script Runner
Send ^o ; File Open
WinWaitActive, Select Script
Send clear_util.rb{ENTER}
WinWaitActive Script Runner
Send ^o ; File Open
WinWaitActive, Select Script
Send clear_util.rb{ENTER}
WinWaitActive Script Runner

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

Send !f ; File
Sleep 500
Send r ; Open Recent
Sleep 500
Send {ENTER}
Sleep 1000
Send !f ; File
Sleep 500
Send r ; Open Recent
Sleep 500
Send {Down}{ENTER}

Click right 220 60
Sleep 500
Click 240 75 ; Close

Click 40 60 ; first tab
Sleep 500
Click 134 150 ; Click and edit
Sleep 500
Send asdfasdf
Sleep 500
Send ^z ; Undo SR-1
Sleep 500
Send ^y ; Redo SR-1
Sleep 500

Click 415 120 ; Click at the end of the first line
Sleep 500
Send +{Home}
Sleep 500
Send ^x ; Cut SR-1
Sleep 500
Send {Down 2}^v ; Paste SR-1
Sleep 500
Send +{Home}^c ; Copy SR-1
Sleep 500
Send {Up 2}^v ; Paste
Sleep 500
Send ^a ; Select all SR-1
Sleep 500
Send ^k ; Comment all SR-1
Sleep 500
Send ^r ; Reload SR-1
WinWaitActive, Discard Changes?
Click 240 95 ; No
WinWaitActive Script Runner
Send ^r ; Reload
WinWaitActive, Discard Changes?
Click 160 95 ; Yes
WinWaitActive Script Runner

Send ^s ; File Save SR-1
Sleep 500
Send !f ; File
Sleep 500
Send a ; Save as
WinWaitActive Save As
Send autohotkey.rb{Enter}
WinWaitActive Script Runner

Send ^f ; Search SR-2
WinWaitActive Find
Send raise
Sleep 500
Send !u ; Direction Up
Sleep 500
Click 25 75 ; Match whole word
Sleep 500
Click 25 100 ; Match case
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send !d ; Direction Down
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Esc}
Sleep 500
Send {F3} ; Find next SR-2
Sleep 500
Send {F3} ; Find next
Sleep 500
Send {F3} ; Find next
Sleep 500
Send {F3} ; Find next
Sleep 500
Send +{F3} ; Find previous SR-2
Sleep 500
Send +{F3} ; Find previous
Sleep 500
Send +{F3} ; Find previous
Sleep 500
Send +{F3} ; Find previous
Sleep 500

Send ^h ; Replace SR-2
WinWaitActive Replace
Send {Tab}blah
Sleep 500
Send !u ; Direction Up
Sleep 500
Click 25 75 ; Match whole word
Sleep 500
Click 25 100 ; Match case
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send !d ; Direction Down
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send {Enter}
Sleep 500
Send !r ; Replace
Sleep 500
Send !r ; Replace
Sleep 500
Send {Esc}
Sleep 500

Send ^w ; Close
WinWaitActive Save
Send y
WinWaitActive Script Runner

Send ^o ; Open
WinWaitActive Select Script
Send autohotkey.rb{Enter}
WinWaitActive Script Runner

Send ^h ; Replace
WinWaitActive Replace
Sleep 500
Send {Backspace 5}prompt
Sleep 500
Send {Tab}raise
Sleep 500
Send !a
Sleep 500
Send {Esc}
WinWaitActive Script Runner

Send ^r ; Reload
WinWaitActive, Discard Changes?
Click 160 95 ; Yes
WinWaitActive Script Runner

Click 145 40 ; Script
Sleep 500
Click 145 60 ; Syntax Check
WinWaitActive Syntax
Send {Enter}
WinWaitActive Script Runner

Click 145 40 ; Script
Sleep 500
Click 145 115 ; Mnemonic Check
WinWaitActive Mnemonic
Send {Enter}
WinWaitActive Script Runner

; Select some lines
Click 415 120 ; Click at the end of the first line
Sleep 100
Send {Home}{Shift down}{Down 2}{Shift up}
Sleep 500

Click 145 40 ; Script
Sleep 500
Click 145 85 ; Syntax Check Selected
WinWaitActive Syntax
Send {Enter}
WinWaitActive Script Runner

Click 145 40 ; Script
Sleep 500
Click 145 135 ; Mnemonic Check Selected
WinWaitActive Mnemonic
Send {Enter}
WinWaitActive Script Runner

Click 145 40 ; Script
Sleep 500
Click 145 170 ; Execute Selected SR-14
Sleep 3000

Click 100 375 ; Click before the last line
Sleep 500
Click 145 40 ; Script
Sleep 500
Click 145 190 ; Execute From Cursor SR-16
Sleep 3000

Click 145 40 ; Script
Sleep 500
Click 145 245 ; View Instrumented SR-19
WinWaitActive Instrumented
Send {Enter}
WinWaitActive Script Runner

Send ^d ; Debug
Sleep 500
Send puts "hi"{Enter}
Sleep 500
Send puts "test"{Enter}
Sleep 500
Send {Up 2}
Sleep 500
Send {Enter}
Sleep 500
Send {Up 2}
Sleep 500
Send {Down 2}
Sleep 500
Send {Esc}
Sleep 500
Send puts "blank"
Sleep 500

Click 320 90 ; Step SR-22
Sleep 500
Click 320 90 ; Step
Sleep 500
Click 320 90 ; Step
Sleep 500
Click 480 90 ; Pause SR-6
Sleep 500
Click 550 90 ; Stop SR-7
Sleep 500

Send ^t ; Toggle Disconnect SR-20
WinWaitActive Disconnect
Send {Enter}
WinWaitActive Script Runner
Sleep 1000

Click right 85 168 ; number = ask...
Sleep 500
Click 85 360 ; Add Breakpoint SR-24
Sleep 500

Click 400 90 ; Start
Sleep 2000 ; Wait for breakpoint
Click 550 90 ; Stop
Sleep 1000

Click right 85 168 ; number = ask...
Sleep 500
Click 85 385 ; Clear Breakpoint
Sleep 1000

Click right 85 200 ; number = ask_string...
Sleep 500
Click 85 393 ; Add Breakpoint
Sleep 1000

Click right 85 248 ; result = message_box...
Sleep 500
Click 85 440 ; Add Breakpoint
Sleep 1000

Click right 100 135 ; right click up near the top
Sleep 500
Click 100 375 ; Clear All Breakpoints
Sleep 1000

Click 400 90 ; Start
WinWaitActive Ask
Sleep 500
Send 5{Enter}
WinWaitActive Script Runner
WinWaitActive Ask
Sleep 500
Send 5{Enter}
WinWaitActive Script Runner
WinWaitActive Message
Sleep 500
Send {Enter}
WinWaitActive Script Runner
WinWaitActive Prompt
Sleep 500
Send {Enter}
WinWaitActive Script Runner
WinWaitActive Prompt
Sleep 500
Send {Enter}
WinWaitActive Script Runner
WinWaitActive Hazardous
Sleep 500
Send n
WinWaitActive Script Runner ; Now paused since we said no
Sleep 500
Click 400 90 ; Go
WinWaitActive Hazardous
Sleep 500
Send {Enter}
WinWaitActive Script Runner
WinWaitActive Hazardous
Sleep 500
Send {Enter}
WinWaitActive Script Runner
WinWaitActive Hazardous
Sleep 500
Send {Enter}
WinWaitActive Script Runner
Sleep 2000

Send ^t ; Toggle Disconnect
WinWaitActive Disconnect
Click 253 73 ; Clear All
Send {Tab}{Enter} ; Confirm dialog
WinWaitActive Script Runner
Sleep 500

; Close everything
Send ^w
Sleep 500
Send ^w
Sleep 500
Send ^w
Sleep 500

Send ^o ; File Open
WinWaitActive Select Script
Send syntax_error.rb{ENTER}
WinWaitActive Script Runner
Click 145 40 ; Script
Sleep 500
Click 145 60 ; Syntax Check SR-18
WinWaitActive Syntax
Send {Enter}
WinWaitActive Script Runner
Click 145 40 ; Script
Sleep 500
Click 145 115 ; Mnemonic Check SR-17
WinWaitActive Mnemonic
Send {Enter}
WinWaitActive Script Runner

Send ^d ; Debug SR-21
Sleep 500
Click 400 90 ; Start
Sleep 1500 ; It should fail immediately SR-8
Click 550 90 ; Stop
Sleep 1000
Click 110 393 ; Click on the error line
Sleep 500
Send ^k ; Comment out the line
Sleep 500
Send ^k ; Uncomment the line
Sleep 500
Send ^k ; Comment out the line
Sleep 500
Click 400 90 ; Start
Sleep 2000 ; It should loop inside the method
Click 480 90 ; Pause
Sleep 1000

Click 145 40 ; Script
Sleep 500
Click 145 275 ; Script Message
WinWaitActive Script Message
Sleep 1000
Send SQA Approves{Enter}
WinWaitActive Script Runner
Sleep 500

Click 145 40 ; Script
Sleep 500
Click 145 296 ; Call Stack
WinWaitActive Call Stack
Sleep 1000
Send {Esc}
WinWaitActive Script Runner

Click right 90 272 ; 'wait 3'
Sleep 1000
Click 125 346 ; Execute selected lines while paused SR-15
WinWaitActive Executing
Click 350 50 ; Pause
Sleep 1000
Send {Esc} ; Try to close the dialog while it is running
Click 460 10 ; Click on the red close button
Sleep 500
Click 430 50 ; Stop
WinWaitActive Script Runner

Click 400 90 ; Go
Sleep 500
Click 560 790 ; Insert Return SR-23
Sleep 4000 ; It should stop
Click 400 90 ; Go
Sleep 1500 ; It should stop
Click 560 95 ; Stop
Sleep 500

Send ^d ; Close Debug
Sleep 500

Sleep 500
Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Script Runner Options
Sleep 500
Click 181 72 ; Monitor limits SR-26
Sleep 500
Click 181 92 ; Pause on red limit SR-27
Sleep 500
Send {Enter} ; Ok
Sleep 500

; Start the CmdTlmServer
Run ruby.exe %A_ScriptDir%/CmdTlmServer
Sleep 4000
WinActivate Script Runner
Sleep 1000

Click 400 90 ; Start
Sleep 500
Send {Enter}
Sleep 10000 ; It should stop because of a red limit
Click 560 95 ; Stop
Sleep 500

Send !f ; File
Sleep 500
Send p ; Options
WinWaitActive Script Runner Options
Sleep 500
Click 181 72 ; Uncheck Monitor limits
Sleep 500
Send {Enter} ; Ok
Sleep 500

; Shut down the CTS
WinActivate Command and Telemetry Server
Sleep 1000
Send ^q
WinWaitActive, Confirm Close
Sleep 500
Send {Enter}

WinActivate Script Runner
Click 145 40 ; Script
Sleep 500
Click 145 222 ; Generate Statistics
WinWaitActive Select
Click 450 250
Sleep 500
Send ^a
Sleep 500
Send {Enter}
WinWaitActive Generation
Sleep 1000
Send {Enter}
WinWaitActive Script Runner
Sleep 2000
Send !f{x}      ; Exit out of Excel
Sleep 500
WinActivate Script Runner

Sleep 500
Click 400 90 ; Start
Sleep 2000

Send ^q ; File Quit
WinWaitActive Warning
Click 215 95 ; No
WinWaitActive Script Runner
Send ^q ; File Quit
WinWaitActive Warning
Click 135 95 ; Yes
WinWaitActive Save
Send n
Sleep 500
