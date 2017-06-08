call bundle exec ruby autohotkey\tools\CmdExtractorAHK --defaultsize
call bundle exec ruby autohotkey\tools\CmdSenderAHK -w 650 -t 650
call bundle exec ruby autohotkey\tools\CmdTlmServerAHK -x 50 -y 50 -w 900 -t 1000
call bundle exec ruby autohotkey\tools\CmdTlmServerAHK2 -w 900 -t 1000 -p -n -c cmd_tlm_server.txt
call bundle exec ruby autohotkey\tools\DataViewerAHK -w 600 -t 800
call bundle exec ruby autohotkey\tools\HandbookCreatorAHK
call bundle exec ruby autohotkey\tools\LauncherAHK
call bundle exec ruby autohotkey\tools\LimitsMonitorAHK
call bundle exec ruby autohotkey\tools\OpenGLBuilderAHK -w 600 -t 600
call bundle exec ruby autohotkey\tools\PacketViewerAHK -w 600 -t 800
call bundle exec ruby autohotkey\tools\PacketViewerAHK2 --defaultsize -p "INST ADCS"
call bundle exec ruby autohotkey\tools\ReplayAHK -w 800
call bundle exec ruby autohotkey\tools\ScriptRunnerAHK -w 600 -t 800
call bundle exec ruby autohotkey\tools\ScriptRunnerAHK2 -w 600 -t 800
call bundle exec ruby autohotkey\tools\TableManagerAHK -w 800 -t 800
call bundle exec ruby autohotkey\tools\TableManagerAHK2 --convert config\tools\table_manager\OldOneDimensionalTable_def.txt
call bundle exec ruby autohotkey\tools\TableManagerAHK3 --convert config\tools\table_manager\OldTwoDimensionalTable_def.txt
call bundle exec ruby autohotkey\tools\TableManagerAHK4 --create config\tools\table_manager\ConfigTables_def.txt -o .
call bundle exec ruby autohotkey\tools\TestRunnerAHK -w 800 -t 800
call bundle exec ruby autohotkey\tools\TestRunnerAHK2 -w 800 -t 800 -c test_runner2.txt
call bundle exec ruby autohotkey\tools\TestRunnerAHK3 -w 800 -t 800 -c test_runner3.txt
call bundle exec ruby autohotkey\tools\TestRunnerAHK4 -w 800 -t 800 -c test_runner4.txt
call bundle exec ruby autohotkey\tools\TestRunnerAHK5 -w 800 -t 800 --suite ExampleTestSuite --group ExampleTest --case test_3xx
REM This test intentionally fails because it is missing a --suite
call bundle exec ruby autohotkey\tools\TestRunnerAHK6 --group ExampleTest --case test_3xx
call bundle exec ruby autohotkey\tools\TlmGrapherAHK -w 800 -t 800
call bundle exec ruby autohotkey\tools\TlmGrapherAHK2 -s -c test2.txt -w 1200 -t 800
call bundle exec ruby autohotkey\tools\TlmGrapherAHK3 -i 'INST HEALTH_STATUS TEMP1'
call bundle exec ruby autohotkey\tools\TlmGrapherAHK4 -s -c bad.txt
call bundle exec ruby autohotkey\tools\TlmExtractorAHK -w 800 -t 800
call bundle exec ruby autohotkey\tools\TlmExtractorAHK2 -c tlm_extractor2.txt -i tlm.bin
call bundle exec ruby autohotkey\tools\TlmExtractorAHK3 -c tlm_extractor2.txt -i tlm.bin -o outputs/logs/tlm.txt
call bundle exec ruby autohotkey\tools\TlmViewerAHK
call bundle exec ruby autohotkey\tools\TlmViewerAHK2 -c tlm_viewer2.txt
REM This test intentionally raises a Unknown keyword KEYWORD error
call bundle exec ruby autohotkey\tools\TlmViewerAHK3 -s "BLAH" -c tlm_viewer3.txt
REM This test intentionally raises a NoMethodError for columns
call bundle exec ruby autohotkey\tools\TlmViewerAHK4 -c tlm_viewer3.txt
call bundle exec ruby autohotkey\tools\TlmViewerAHK5 -n -s "INST ADCS"

REM Display any exception files that were generated
dir autohotkey\outputs\logs\*exception.txt
