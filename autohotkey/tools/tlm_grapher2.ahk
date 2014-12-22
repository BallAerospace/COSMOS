SetWinDelay 500
WinWaitActive Telemetry Grapher

Sleep 22000 ; 20s of data

Click 215 100 ; Pause the graph
Sleep 500

Click 347 95 ; Tab 2 just to see it
Sleep 2000
Click 300 95 ; Back to Tab 1
Sleep 500

Click 1111, 468, 2 ; Double click the error icon
Sleep 1000
Send {Enter}
Sleep 500

Click right 72 282
Sleep 500
Send {Down 2}{Enter}
WinWaitActive Warning
Send y
Sleep 500

MouseMove 344, 200 ; Mouse over the top graph
Sleep 1000
Click down
MouseMove 500, 200, 50 ; Move back and forth to show popups
Click up
MouseMove 344, 200, 50
Sleep 500

Click 185 135 ; Click in the Second Plotted
Sleep 500
Send {Backspace 7}5{Enter} ; Display 5s
Sleep 1000

; Lasso select on the overview graph
MouseMove 700, 760
Click down
MouseMove 850, 760, 40
Click up
SLeep 1000

Click 360 760 ; Click on the overview to make it go back to the beginning
Sleep 1000

; Shrink the left side of the overview graph
MouseMove 292, 760
Click down
MouseMove 250, 760, 40
MouseMove 500, 760, 40
MouseMove 340, 760, 40
Click up
Sleep 1000

Click 1150 760 ; Click on the overview to make it go to the end
Sleep 1000

; Shrink the right side of the overview graph
MouseMove 1182, 760
Click down
MouseMove 1220, 760, 40
MouseMove 900, 760, 40
MouseMove 1150, 760, 40
Click up
Sleep 1000

; Drag the overview graph back to the left, right, and middle
MouseMove 1100, 760
Click down
MouseMove 250, 760, 60
MouseMove 1220, 760, 60
MouseMove 750, 760, 60
Click up
Sleep 1000

; Manipulate the overview graph using the arrow keys
Loop 10
{
  Send {Up}
  Sleep 100
}
Loop 35
{
  Send {Down}
  Sleep 100
}
Loop 10
{
  Send {Left}
  Sleep 200
}
Loop 10
{
  Send {Right}
  Sleep 200
}

; Shut down the CTS
WinActivate, Command and Telemetry Server
Sleep 500
Send ^q
WinWaitActive, Confirm Close
Send {Enter}

Sleep 2000

; Quit Telemetry Grapher
WinActivate Telemetry Grapher
Send ^q
WinWaitActive Save
Send n

