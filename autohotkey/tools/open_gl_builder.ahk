SetWinDelay 500
SetKeyDelay 10
WinWaitActive OpenGL

Send ^o
WinWaitActive Open
Send error.txt{Enter}
WinWaitActive Error
Click 450 250
WinWaitActive OpenGL

Send ^a ; Open shape
WinWaitActive Add
Click 215 105 ; Cancel
Sleep 500
Send ^a ; Open shape
WinWaitActive Add
Send {Enter}
WinWaitActive Select
Send diamond.STL{Enter}
WinWaitActive Add
Click 83 106
WinWaitActive OpenGL

; Change the perspective
Send ^p
Sleep 500
Send ^t
Sleep 500
Send ^b
Sleep 500
Send ^f
Sleep 500
Send ^w
Sleep 500
Send ^l
Sleep 500
Send ^r
Sleep 500

; Change the scene
Send ^e
Sleep 500
Send ^m
Sleep 500
Send ^s
Sleep 500

Click 300 400
Sleep 500
Click WheelUp 20
Sleep 500
Click WheelDown 30
Sleep 500
Click 300 400

Send {a 20}
Sleep 500
Send +{a 20}
Sleep 500
Send {r 20}
Sleep 500
Send +{r 20}
Sleep 500
Send {g 20}
Sleep 500
Send +{g 20}
Sleep 500
Send {b 20}
Sleep 500
Send +{b 20}
Sleep 500

Loop 50
{
  Send {x down}
}
Send {x up}
Loop 50
{
  Send {y down}
}
Send {y up}
Loop 50
{
  Send {z down}
}
Send {z up}
Loop 50
{
  Send +{x down}
}
Send {x up}
Loop 50
{
  Send +{y down}
}
Send {y up}
Loop 50
{
  Send +{z down}
}
Send {z up}

Click down 100, 100
MouseMove 100, 500, 10
MouseMove 500, 500, 10
MouseMove 500, 100, 10
MouseMove 100, 100, 10
Click up
Sleep 500
Click down right 100, 100
MouseMove 200, 100, 10
MouseMove 100, 100, 10
Click up right
Sleep 500

Send ^x ; Export
WinWaitActive Export
Send {Enter}
WinWaitActive OpenGL

Send ^e ; change something
Sleep 1000
Send ^o
WinWaitActive Open
Send scene.txt{Enter}
WinWaitActive OpenGL
Sleep 500

; Quit OpenGL Builder
Send ^q
Sleep 500
