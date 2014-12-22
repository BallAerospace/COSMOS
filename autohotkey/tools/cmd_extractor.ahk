SetWinDelay 500
WinWaitActive Command Extractor
Sleep 500
Send ^r ; Mode->Include Raw Data CE-3
Sleep 500
Click 500 71 ; Browse
Sleep 1000
Send cmd.bin{Enter}
WinWaitActive Command Extractor
Click 200 422 ; Process Files
WinWaitActive Log File
Click 450 305 ; Cancel
WinWaitActive Command Extractor
sleep 500
Click 200 422 ; Process Files
Sleep 500
Send {Enter} ; Overwrite Yes
Sleep 5000 ; Allow the file to be processed CE-1
Send {Enter}
WinWaitActive Command Extractor
Click 460 422 ; Open in Text Editor CE-2
Sleep 5000
Send !f{x}      ; Exit text editor
WinActivate Command Extractor
WinWaitActive Command Extractor
Send ^q

