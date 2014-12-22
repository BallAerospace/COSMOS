SetWinDelay 500
WinWaitActive Test Runner
Sleep 1000
Click 630 130 ; Start Test Case
WinWaitActive Warning
Send {Tab}{Enter}
WinWaitActive Test Runner
Click 630 130 ; Start Test Case TR-3
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 630 100 ; Start Test Group TR-2
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 700 100 ; Setup Test Group TR-4
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 770 100 ; Teardown Test Group TR-4
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite TR-1
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 700 70 ; Setup Test Suite TR-5
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 770 70 ; Teardown Test Suite TR-5
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 100 ; Check Continue after Error TR-11
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 125 ; Check Abort after Error TR-12
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 100 ; Uncheck Continue after Error
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 125 ; Uncheck Abort after Error
Sleep 500
Click 60 70 ; Check Pause on Error TR-10
Sleep 500
Click 630 70 ; Start Test Suite
Sleep 5000

Click 64 40 ; Script Menu
Sleep 500
Click 64 128 ; Toggle Debug TR-9
Sleep 500
Send puts $manual{Enter} ; TR-16
Sleep 1000
Send puts $loop_testing{Enter} ; TR-15
Sleep 1000

Click 600 195 ; Skip
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
Sleep 5000
Click 760 195 ; Stop
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 100 ; Check Continue after Error
Sleep 500
Click 630 70 ; Start Test Suite
Sleep 5000
Click 680 195 ; Retry
Sleep 1000
Click 65 40 ; Script
Sleep 500
Click 65 65 ; Test Results Message
WinWaitActive Test Results
Sleep 1000
Send QA Approves{Enter}
WinWaitActive Test Runner
Sleep 500
Click 65 40 ; Script
Sleep 500
Click 65 86 ; Script Message
WinWaitActive Script Message
Sleep 1000
Send SQA Approves{Enter}
WinWaitActive Test Runner
Sleep 500
Click 65 40 ; Script
Sleep 500
Click 65 108 ; Show Call Stack
WinWaitActive Call Stack
Sleep 1000
Send {Esc}
WinWaitActive Test Runner
Click 600 195 ; Go
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
Sleep 5000
Click 760 195 ; Stop
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 60 125 ; Check Abort after Error
Sleep 500
Click 630 70 ; Start Test Suite
Sleep 5000
Click 600 195 ; Go
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 250 70 ; Check Manual
Sleep 500
Click 630 70 ; Start Test Suite
Sleep 5000
Click 600 195 ; Go
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 250 100 ; Check Loop Testing TR-13
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Tab}{Enter} ; No
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
Sleep 7000
Click 600 195 ; Go
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 60 70 ; Uncheck Pause on Error
Sleep 500
Click 60 100 ; Uncheck Continue after Error
Sleep 500
Click 60 125 ; Uncheck Abort after Error
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Warning
Send {Enter}
Sleep 10000
Click 760 195 ; Stop
WinWaitActive Results
Send {Enter}
WinWaitActive Test Runner
Click 250 125 ; Check Break after Error TR-14
Sleep 500
Click 630 70 ; Start Test Suite
WinWaitActive Warning
Send {Enter}
WinWaitActive Warning
Send {Enter}
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Send ^r ; Show Results TR-6, TR-8
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 250 100 ; Uncheck Loop Testing
Sleep 500
Click 60 70 ; Check Pause on Error
Sleep 500
Send ^s ; Test Selection
WinWaitActive Test Selection
Click 31 111 ; Expand suite
Sleep 500
Click 50 111 ; Select suite
Sleep 500
Click 50 420 ; Select other suite
Sleep 500
Click 69 199 ; Select ExampleTest
Sleep 500
Click 69 199 ; Deselect ExampleTest
Sleep 500
Click 90 309 ; Select test_3xx
Sleep 500
Send {Enter}
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Send ^s ; Test Selection TR-7
WinWaitActive Test Selection
Click 50 111 ; Select suite
Sleep 500
Send {Enter}
WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
Sleep 6000
Click 600 195 ; Skip
WinWaitActive Results
Send {Enter}

WinWaitActive Test Runner
Click 630 70 ; Start Test Suite
Sleep 6000

Send ^q ; File Quit
WinWaitActive Warning
Send {Enter} ; No
Sleep 2000
Send ^q ; File Quit
WinWaitActive Warning
Send {Tab}{Enter} ; Yes
Sleep 1000
Send {Enter}

