---
layout: docs_v4
title: Launcher
toc: true
---

## Launcher Configuration

Launcher configuration files define the icons and buttons presented in the Launcher and define how programs are launched. These files are expected to be placed in the config/tools/launcher directory and have a .txt extension. The default configuration file is named launcher.txt.

To specify a different configuration file add '--config launcher.txt' when starting the Launcher. For example, on Windows create a new Batch file at the top of your COSMOS configuration that looks like the following:
{% highlight bash %}
call tools\Launcher.bat --config launcher_config.txt
{% endhighlight %}

<div style="clear:both;"></div>

On Linux create a new executable file at the top of your COSMOS configuration that looks like the following:
{% highlight bash %}
ruby tools\Launcher --config launcher_config.txt
{% endhighlight %}

<div style="clear:both;"></div>

{% cosmos_meta launcher.yaml %}

## Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/launcher/launcher.txt**

{% highlight bash %}
TITLE "Demo Launcher"
FONT tahoma 12
NUM_COLUMNS 4
MULTITOOL_START "COSMOS" NULL
TOOL "RUBYW tools/CmdTlmServer -x 827 -y 2 -w 756 -t 475 -c cmd_tlm_server.txt"
DELAY 5
TOOL "RUBYW tools/TlmViewer -x 827 -y 517 -w 424 -t 111"
TOOL "RUBYW tools/PacketViewer -x 827 -y 669 -w 422 -t 450"
TOOL "RUBYW tools/ScriptRunner -x 4 -y 2 -w 805 -t 545"
TOOL "RUBYW tools/CmdSender -x 4 -y 586 -w 805 -t 533"
MULTITOOL_END
TOOL "Command and Telemetry Server" "RUBYW tools/CmdTlmServer" "cts.png" --config cmd_tlm_server.txt
TOOL "Limits Monitor" "RUBYW tools/LimitsMonitor" "limits_monitor.png"
DIVIDER
LABEL "Commanding and Scripting"
TOOL "Command Sender" "RUBYW tools/CmdSender" "cmd_sender.png"
TOOL "Script Runner" "RUBYW tools/ScriptRunner" "script_runner.png"
TOOL "Test Runner" "RUBYW tools/TestRunner" "test_runner.png"
DIVIDER
LABEL Telemetry
TOOL "Packet Viewer" "RUBYW tools/PacketViewer" "packet_viewer.png"
TOOL "Telemetry Viewer" "RUBYW tools/TlmViewer" "tlm_viewer.png"
TOOL "Telemetry Grapher" "RUBYW tools/TlmGrapher" "tlm_grapher.png"
TOOL "Data Viewer" "RUBYW tools/DataViewer" "data_viewer.png"
DIVIDER
LABEL Utilities
TOOL "Telemetry Extractor" "RUBYW tools/TlmExtractor" "tlm_extractor.png"
TOOL "Command Extractor" "RUBYW tools/CmdExtractor" "cmd_extractor.png"
TOOL "Handbook Creator" "RUBYW -Ku tools/HandbookCreator" "handbook_creator.png"
TOOL "Table Manager" "RUBYW tools/TableManager" "table_manager.png"
{% endhighlight %}

{% cosmos_cmd_line Launcher %}
