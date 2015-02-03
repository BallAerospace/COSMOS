ruby autohotkey\tools\CmdExtractorAHK --defaultsize
ruby autohotkey\tools\CmdSenderAHK -w 650 -t 650
ruby autohotkey\tools\CmdTlmServerAHK -x 50 -y 50 -w 900 -t 1000
ruby autohotkey\tools\CmdTlmServerAHK2 -w 900 -t 1000 -p -n -c cmd_tlm_server.txt
ruby autohotkey\tools\DataViewerAHK -w 600 -t 800
ruby autohotkey\tools\HandbookCreatorAHK
ruby autohotkey\tools\LauncherAHK
ruby autohotkey\tools\LimitsMonitorAHK
ruby autohotkey\tools\OpenGLBuilderAHK -w 600 -t 600
ruby autohotkey\tools\PacketViewerAHK -w 600 -t 800
ruby autohotkey\tools\PacketViewerAHK2 --defaultsize -p "INST ADCS"
ruby autohotkey\tools\ReplayAHK
ruby autohotkey\tools\ScriptRunnerAHK -w 600 -t 800
ruby autohotkey\tools\ScriptRunnerAHK2 -w 600 -t 800
ruby autohotkey\tools\TableManagerAHK -w 800 -t 800
ruby autohotkey\tools\TestRunnerAHK -w 800 -t 800
ruby autohotkey\tools\TestRunnerAHK2 -w 800 -t 800 -c test_runner2.txt
ruby autohotkey\tools\TestRunnerAHK3 -w 800 -t 800 -c test_runner3.txt
ruby autohotkey\tools\TestRunnerAHK4 -w 800 -t 800 -c test_runner4.txt
ruby autohotkey\tools\TlmGrapherAHK -w 800 -t 800
ruby autohotkey\tools\TlmGrapherAHK2 -s -c test2.txt -w 1200 -t 800
ruby autohotkey\tools\TlmGrapherAHK3 -i 'INST HEALTH_STATUS TEMP1'
ruby autohotkey\tools\TlmGrapherAHK4 -s -c bad.txt
ruby autohotkey\tools\TlmExtractorAHK -w 800 -t 800
ruby autohotkey\tools\TlmExtractorAHK2 -c tlm_extractor2.txt -i tlm.bin
ruby autohotkey\tools\TlmExtractorAHK3 -c tlm_extractor2.txt -i tlm.bin -o outputs/logs/tlm.txt
ruby autohotkey\tools\TlmViewerAHK
ruby autohotkey\tools\TlmViewerAHK2 -c tlm_viewer2.txt
ruby autohotkey\tools\TlmViewerAHK3 -s "BLAH" -c tlm_viewer3.txt
ruby autohotkey\tools\TlmViewerAHK4 -c tlm_viewer3.txt
ruby autohotkey\tools\TlmViewerAHK5 -n -s "INST ADCS"

REM Display any exception files that were generated
dir autohotkey\outputs\logs\*exception.txt
