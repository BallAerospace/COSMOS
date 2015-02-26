---
layout: docs
title: Tool Configuration
permalink: /docs/tools/
---

Please see [Telemetry Screen Configuration](/docs/screens) for instructions on configuring Telemetry Viewer.

* * *

## Launcher Configuration

Launcher configuration files define the icons and buttons presented in the Launcher and define how programs are launched. These files are expected to be placed in the config/tools/launcher directory and have a .txt extension. The default configuration file is named launcher.txt.

## Keywords:

### TITLE

The TITLE keyword changes the title of the COSMOS Launcher.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Title</td>
<td>Launcher title. Defaults to "COSMOS Launcher" without this keyword.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TITLE 'Program Launcher'
{% endhighlight %}

### TOOL_FONT

The TOOL_FONT keyword sets the font used for tool buttons. It should only be used once as the last encountered setting will apply to all button labels. The default font if this keyword is not used is 12px Arial.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Font Family</td>
<td>The font family to use. Valid choices are "Arial", "Calibri", "Cambria", "Candara", "Castellar", "Centaur", "Century", "Chiller", "Consolas", "Constantia", "Courier", "Courier New", "Dotum", "Elephant", "Euphemia", "Fixedsys", "Georgia", "Impact", "Lucida", "Papyrus", "Rockwell", "Rod", "System", "Tahoma", "Terminal", "Times New Roman", "Verdana", "Wide Latin".</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Font Size</td>
<td colspan="1">The size of the font in standard points.</td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TOOL_FONT Courier 10
{% endhighlight %}

### LABEL_FONT

The LABEL_FONT keyword sets the font used for labels. It should only be used once as the last encountered setting will apply to all labels. The default font if this keyword is not used is 16px Tahoma.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Font Family</td>
<td>The font family to use. Valid choices are "Arial", "Calibri", "Cambria", "Candara", "Castellar", "Centaur", "Century", "Chiller", "Consolas", "Constantia", "Courier", "Courier New", "Dotum", "Elephant", "Euphemia", "Fixedsys", "Georgia", "Impact", "Lucida", "Papyrus", "Rockwell", "Rod", "System", "Tahoma", "Terminal", "Times New Roman", "Verdana", "Wide Latin".</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Font Size</td>
<td colspan="1">The size of the font in standard points.</td>
<td colspan="1">Yes</td></tr></tbody></table>

{% highlight bash %}
Example Usage:
LABEL_FONT Arial 20
{% endhighlight %}

### LABEL

The LABEL keyword creates a label of text in the current font style.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Text</td>
<td>The text of the label.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
LABEL Utilities
{% endhighlight %}

### DIVIDER

The DIVIDER keyword creates a horizontal line between tools. It takes no parameters and is purely for decoration.

### NUM_COLUMNS

The NUM_COLUMNS keyword specifies how launcher buttons should be created per row in the GUI. The default is 4.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Columns</td>
<td>The number of launcher buttons per row before Launcher automatically creates a new row of buttons.</td>
<td>Yes</td></tr></tbody></table>

### TOOL

The TOOL keyword specifies one tool that can be launched. The syntax varies if it is being used standalone or for a multi-tool.

Syntax when standalone:

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Button Text</td>
<td><span style="color: rgb(0,0,0);">Label that is put on the button that launches the tool</span></td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Shell Command</td>
<td colspan="1">Command that is executed to launch the tool. (The same thing you would type at a command terminal). Note that you can include tool parameters here which will be applied when the tool starts.</td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Icon Filename</td>
<td colspan="1">Filename of a an icon located in the data directory. Passing 'nil' or an empty string '' will result in Launcher using the default COSMOS icon.</td>
<td colspan="1">No</td></tr>
<tr>
<td colspan="1"><span style="color: rgb(0,0,0);">Tool Parameters</span></td>
<td colspan="1"><span style="color: rgb(0,0,0);">Tool parameters as you would type on the command line. Specifying parameters here rather than in "Shell Command" will cause a dialog box to appear which allows the user to edit parameters if desired. Expected to be in parameter name/parameter value pairs. i.e. &mdash;config filename.txt. NOTE: The full configuration option name must be used rather than the short name. NOTE: These parameters will override any parameters specified in the Shell Command.</span></td>
<td colspan="1">No</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TOOL "Command and Telemetry Server" "RUBYW tools/CmdTlmServer" cts.png --config cmd_tlm_server.txt
TOOL "Script Runner" "RUBYW tools/ScriptRunner" nil --width 600 --height 800
{% endhighlight %}

Syntax when used within the MULTITOOL keywords:

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td colspan="1">Shell Command</td>
<td colspan="1">Command that is executed to launch the tool. (The same thing you would type at a command terminal)</td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage: See MULTITOOL_START

### MULTITOOL_START

The MULTITOOL_START keyword starts the creation of a single icon/button that will launch multiple tools.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Button Text</td>
<td><span style="color: rgb(0,0,0);">Label that is put on the button that launches the tools</span></td>
<td>Yes</td></tr>
<tr>
<td colspan="1"><span>Icon Filename</span></td>
<td colspan="1"><span>Filename of a an icon located in the data directory. Passing 'nil' or an empty string '' will result in Launcher using the default COSMOS icon.</span></td>
<td colspan="1">No</td></tr></tbody></table>

{% highlight bash %}
Example Usage:
MULTITOOL_START "COSMOS"
  TOOL "RUBYW tools/CmdTlmServer -x 827 -y 2 -w 756 -t 475 -c cmd_tlm_server.txt"
  DELAY 5
  TOOL "RUBYW tools/TlmViewer -x 827 -y 517 -w 424 -t 111"
MULTITOOL_END
{% endhighlight %}

### MULTITOOL_END

The MULTITOOL_END keyword ends the creation of a multi-tool button.

Example Usage: See MULTITOOL_START

### DELAY

The DELAY keyword inserts a delay between launching multiple tools. It is only valid within the MULTITOOL keywords.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Delay</td>
<td>Time to delay in seconds</td>
<td>Yes</td></tr></tbody></table>

Example Usage: See MULTITOOL_START

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

* * *


## Limits Monitor Configuration

Limits Monitor has the ability to ignore telemetry items and no longer monitor them for transition to the yellow and red state. This is useful for known telemetry item configuration problems. Note that while telemetry items may be ignored in Limits Monitor, their states are still being recorded by the Command and Telemetry Server.

## Keywords:

### IGNORE

The IGNORE keyword instructs Limits Monitor to ignore a particular telemetry item when reporting the overall system limits state.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Target Name</td>
<td>Name of the telemetry target</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Packet Name</td>
<td colspan="1">Name of the telemetry packet</td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Item Name</td>
<td colspan="1">Name of the telemetry item</td>
<td colspan="1">Yes</td></tr></tbody></table>


Example Usage:
{% highlight bash %}
IGNORE INST HEALTH_STATUS TEMP1
IGNORE INST HEALTH_STATUS TEMP2
{% endhighlight %}

* * *


## Script Runner Configuration

The Script Runner Configuration File affects both the Script Runner tool and the Test Runner tool. It defines where to look for procedures and other scripting settings. The configuration file is named script_runner.txt.

## Keywords:

### LINE_DELAY

The LINE_DELAY keyword specifies the amount of time in seconds before the next line of a script will be executed. This allows the user to easily watch as a script progresses.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Delay</td>
<td>Delay in seconds before the next line is executed. A value of 0 means to execute the scripts as fast as possible.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
LINE_DELAY 1.0 # Delay for 1 second between lines
{% endhighlight %}

### MONITOR_LIMITS

The MONITOR_LIMITS keyword specifies that Script Runner should log limits events while a script is running. These limit evens will be printed in the script runner log file. Note that this has no effect of the Command and Telemetry Server which always logs limits events.

### PAUSE_ON_RED

The PAUSE_ON_RED keyword specifies that Script Runner should pause a running script if a red limit occurs

## Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/script_runner/script_runner.txt**

{% highlight bash %}
LINE_DELAY 0.1
MONITOR_LIMITS
PAUSE_ON_RED
{% endhighlight %}

* * *

## Telemetry Extractor Configuration

Telemetry Extractor configuration files define what telemetry points that telemetry extractor should pull out of a log file. These files are expected to be placed in the tools/config/tlm_extractor directory and have a .txt extension. The default configuration file is named tlm_extractor.txt.

## Keywords:

### DELIMITER

The DELIMITER keyword specifies an alternative column delimiter over the default of a tab character.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Delimiter</td>
<td>Character or string to use as a delimiter. For example ','.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
DELIMITER ','
{% endhighlight %}

### FILL_DOWN

The FILL_DOWN keyword causes Telemetry Extractor it to insert a value into every row of the output. For example, if you have the following telemetry extractor configuration file:

{% highlight bash %}
ITEM INST HEALTH_STATUS PKTID
ITEM INST HEALTH_STATUS COLLECTS
ITEM INST ADCS POSX
ITEM INST ADCS POSX
{% endhighlight %}

Your normal output might look something like this:

<table><colgroup><col /> </colgroup>
<tbody>
<tr>
<td>TARGET</td>
<td>PACKET</td>
<td>PKTID</td>
<td>COLLECTS</td>
<td>POSX</td>
<td>POSX</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td> </td>
<td> </td>
<td>-579296</td>
<td>-579296</td></tr>
<tr>
<td>INST</td>
<td>HEALTH_STATUS</td>
<td>1</td>
<td>0</td>
<td> </td>
<td> </td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td> </td>
<td> </td>
<td>-578683</td>
<td>-578683</td></tr></tbody></table>

with FILL_DOWN enabled it would like this this:

<table><colgroup><col /> </colgroup>
<tbody>
<tr>
<td>TARGET</td>
<td>PACKET</td>
<td>PKTID</td>
<td>COLLECTS</td>
<td>POSX</td>
<td>POSX</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td> </td>
<td> </td>
<td>-579296</td>
<td>-579296</td></tr>
<tr>
<td>INST</td>
<td>HEALTH_STATUS</td>
<td>1</td>
<td>0</td>
<td>-579296</td>
<td>-579296</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td>1</td>
<td>0</td>
<td>-578683</td>
<td>-578683</td></tr></tbody></table>

Note that in the second INST ADCS packet the PKTID and COLLECTS values are "filled down" even though they were not present in that packet. This makes it easier to graph multiple values across packets in Excel.

### DOWNSAMPLE_SECONDS

The DOWNSAMPLE_SECONDS keyward causes Telemetry Extractor to downsample data to only output a value every X seconds of time.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Seconds</td>
<td>Number of seconds to skip between values output</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
DOWNSAMPLE_SECONDS 5
{% endhighlight %}

### MATLAB_HEADER

The MATLAB_HEADER keyword cause Telemetry Extractor to prepend the Matlab comment symbol of '%' to the header lines in the output file.

### UNIQUE_ONLY

The UNIQUE_ONLY keyword causes Telemetry Extractor to only output a row if one of the extracted values has changed. This can be used to extract telemetry items over a large time period by only outputting those values where items have changed.

### UNIQUE_IGNORE

The UNIQUE_IGNORE keyword is used in conjunction with UNIQUE_ONLY to control which items should be checked for changing values. This list of telemetry items (not target names or packet names) always includes the COSMOS metadata items named RECEIVED_TIMEFORMATTED and RECEIVED_SECONDS. This is because these items will always change from packet to packet which would cause them to ALWAYS be printed if UNIQUE_ONLY was used. To avoid this, but still include time stamps in the output, UNIQUE_IGNORE includes these items. If you have a similar telemetry item that you want to display in the output, but not be used to determine uniqueness, use this keyword.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Item Name</td>
<td>Name of the item to exclude from the uniqueness criteria (see above). Note that all items with this name in all target packets are affected.</td>
<td>Yes</td></tr></tbody></table>

### SHARE_COLUMNS

The SHARE_COLUMNS keyword causes Telemetry Extractor to put telemetry items with the same name into the same column in the output. For example if you have the following configuration file:

{% highlight bash %}
ITEM INST HEALTH_STATUS PKTID
ITEM INST ADCS PKTID
{% endhighlight %}

Your normal output would look something like this:

<table><colgroup><col /> </colgroup>
<tbody>
<tr>
<td>TARGET</td>
<td>PACKET</td>
<td>PKTID</td>
<td>PKTID</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td> </td>
<td>1</td></tr>
<tr>
<td>INST</td>
<td>HEALTH_STATUS</td>
<td>1</td>
<td> </td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td> </td>
<td>1</td></tr></tbody></table>

Note how both telemetry packets got their own unique PKTID column. With SHARE_COLUMNS enabled you would get something like this:

<table><colgroup><col /> </colgroup>
<tbody>
<tr>
<td>TARGET</td>
<td>PACKET</td>
<td>PKTID</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td>1</td></tr>
<tr>
<td>INST</td>
<td>HEALTH_STATUS</td>
<td>1</td></tr>
<tr>
<td>INST</td>
<td>ADCS</td>
<td>1</td></tr></tbody></table>

Note how both packets share the one PKTID column. This applies to all telemetry items with identical names.

### DONT_OUTPUT_FILENAMES

The DONT_OUTPUT_FILENAMES keyword prevents Telemetry Extractor from outputing the list of input filenames at the top of each output file.

### TEXT

The TEXT keyword allows you to place arbitrary text in the Telemetry Extractor output. It also allows you to dynamically create Excel formulas using a special syntax.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td colspan="1">Header</td>
<td colspan="1">The column header text</td>
<td colspan="1">Yes</td></tr>
<tr>
<td>Text</td>
<td>Text to put in the output file. The special character '%' will be translated to the current row of the output file. This is useful for Excel formulas which need a reference to a cell. Remember the first two columns are always the TARGET and PACKET and telemetry items start in column 'C' in Excel.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TEXT "Calc" "=C%*D%" # Excel will calculate the C column times the D column
{% endhighlight %}

### ITEM

The ITEM keyword specifies a telemetry item to extract.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td colspan="1">Target Name</td>
<td colspan="1">Name of the telemetry target</td>
<td colspan="1">Yes</td></tr>
<tr>
<td>Packet Name</td>
<td>Name of the telemetry packet</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Item Name</td>
<td colspan="1">Name of the telemetry item</td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Item Type</td>
<td colspan="1"><span style="color: rgb(0,0,0);">RAW, FORMATTED, or WITH_UNITS (CONVERTED is implied if the parameter is omitted)</span></td>
<td colspan="1">No</td></tr></tbody></table>

## Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/tlm_extractor/tlm_extractor.txt**

{% highlight bash %}
FILL_DOWN
MATLAB_HEADER
DELIMITER ","
SHARE_COLUMNS
DOWNSAMPLE_SECONDS 5
{% endhighlight %}

DONT_OUTPUT_FILENAMES

{% highlight bash %}
UNIQUE_ONLY
UNIQUE_IGNORE TEMP1
ITEM INST HEALTH_STATUS TIMEFORMATTED
ITEM INST HEALTH_STATUS TEMP1 RAW
ITEM INST HEALTH_STATUS TEMP2 FORMATTED
ITEM INST HEALTH_STATUS TEMP3 WITH_UNITS
ITEM INST HEALTH_STATUS TEMP4
TEXT "Calc" "=D%*G%" # Calculate TEMP1 (RAW) times TEMP4
{% endhighlight %}


* * *

## Test Runner Configuration

Test Runner configuration files define what tests should be run with what options. These files are expected to be placed in the tools/config/test_runner directory and have a .txt extension. The default configuration file is named test_runner.txt.

## Keywords:

### REQUIRE_UTILITY

The REQUIRE_UTILITY keyword specifies a test procedure to run. This procedure will be found automatically in the procedures directory or can be given by a path relative to the COSMOS install directory or by an absolute path.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Filename</td>
<td>Name of the test file</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
REQUIRE_UTILITY example_test # .rb is optional
REQUIRE_UTILITY ../../example_test # Relative path from the base of the COSMOS configuration
REQUIRE_UTILITY C:/procedures/example_test # Absolute path (not cross platform)
{% endhighlight %}

### RESULTS_WRITER

The RESULTS_WRITER keyword allows you to specify a different Ruby file to interpret and print the Test Runner results. This file must define a class which implements the Cosmos::ResultsWriter API.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Filename</td>
<td>Name of the Ruby file which implements a results writer</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Class Parameters</td>
<td colspan="1">Parameters to pass to the constructor of the results writer</td>
<td colspan="1">Class specific</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
RESULTS_WRITER my_results_writer.rb
{% endhighlight %}

### ALLOW_DEBUG

Whether to allow the user to enable the debug line where the user can enter arbitrary statements.

### PAUSE_ON_ERROR

The PAUSE_ON_ERROR keyword sets or clears the pause on error checkbox. If this is checked, Test Runner will pause if the test encounters an error. Otherwise the error will be logged but the script will continue.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to pause when the script encounters an error</td>
<td>Yes</td></tr></tbody></table>


Example Usage:
{% highlight bash %}
PAUSE_ON_ERROR TRUE # default
{% endhighlight %}

### CONTINUE_TEST_CASE_AFTER_ERROR

The CONTINUE_TEST_CASE_AFTER_ERROR keyword sets or clears the continue test case after error checkbox. If this is checked, Test Runner will continue executing the current test case after encountering an error. Otherwise the test case will stop at the error and the next test case will execute.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to continue the test case when the script encounters an error</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
CONTINUE_TEST_CASE_AFTER_ERROR TRUE # default
{% endhighlight %}

### ABORT_TESTING_AFTER_ERROR

The ABORT_TESTING_AFTER_ERROR keyword sets or clears the abort testing after error checkbox. If this is checked, Test Runner will stop executing after the current test case completes (how it completes depends on CONTINUE_TEST_CASE_AFTER_ERROR). Otherwise the next test case will execute.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to continue to the next test case when the script encounters an error</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
ABORT_TESTING_AFTER_ERROR FALSE # default
{% endhighlight %}

### MANUAL

The MANUAL keyword sets the $manual global variable for all executing scripts. This variable can be checked during tests to allow for fully automated tests if it is not set, or for user input if it is set.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to set the $manual global to true</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
MANUAL TRUE # default
{% endhighlight %}

### LOOP_TESTING

The LOOP_TESTING keyword sets or clears the loop testing checkbox. If this is checked, Test Runner will continue to run whatever level of tests that were initially started. If either "Abort Testing after Error" or "Break Loop after Error" are checked, then the loop testing will stop if an error is encountered. The difference is that the "Abort Testing after Error" will stop testing immediately after the current test case completes. "Break Loop after Error" continues the current loop by executing the remaining suite or group before stopping. In the case of executing a single test case the options effectively do the same thing.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to loop the selected test level</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
LOOP_TESTING FALSE # default
{% endhighlight %}

### BREAK_LOOP_AFTER_ERROR

The BREAK_LOOP_AFTER_ERROR keyword sets or clears the break loop after error checkbox. If this is checked, Test Runner continues the current loop by executing the remaining suite or group before stopping.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>True or False</td>
<td>Whether to break the loop after encountering an error</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
BREAK_LOOP_AFTER_ERROR FALSE # default
{% endhighlight %}

### IGNORE_TEST

The IGNORE_TEST keyword ignores the given test class name when parsing the tests.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Test Class Name</td>
<td>The test class to ignore when building the list of available tests</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
IGNORE_TEST ExampleTest
{% endhighlight %}

### IGNORE_TEST_SUITE

The IGNORE_TEST_SUITE keyword ignores the given test suite name when parsing the tests.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Test Suite Name</td>
<td>The test suite to ignore when building the list of available test suites</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
IGNORE_TEST_SUITE ExampleTestSuite
{% endhighlight bash %}

### CREATE_DATA_PACKAGE

The CREATE_DATA_PACKAGE keyword creates a data package of every file created during the test.

Example Usage:

{% highlight bash %}
CREATE_DATA_PACKAGE
{% endhighlight %}

### AUTO_CYCLE_LOGS

The AUTO_CYCLE_LOGS automatically starts a new server message log and cmd/tlm logs at the beginning and end of each test.  Very useful when coupled with the CREATE_DATA_PACKAGE keyword.

Example Usage:
{% highlight bash %}
AUTO_CYCLE_LOGS
{% endhighlight %}

### COLLECT_META_DATA

The COLLECT_META_DATA keyword tells TestRunner to prompt for Meta Data before starting tests.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td colspan="1">Target Name</td>
<td colspan="1">Meta Data Target Name</td>
<td colspan="1">Yes</td></tr>
<tr>
<td>Packet Name</td>
<td>Meta Data Packet Name</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
COLLECT_META_DATA META DATA
{% endhighlight %}

### Script Runner Configuration Keywords

Test Runner also responds to all the keywords in the Script Runner Configuration.

### Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/test_runner/test_runner.txt**

{% highlight bash %}
REQUIRE_UTILITY example_test
ALLOW_DEBUG
PAUSE_ON_ERROR TRUE
CONTINUE_TEST_CASE_AFTER_ERROR TRUE
ABORT_TESTING_AFTER_ERROR FALSE
MANUAL TRUE
LOOP_TESTING TRUE
BREAK_LOOP_AFTER_ERROR TRUE
IGNORE_TEST ExampleTest
IGNORE_TEST_SUITE ExampleTestSuite

CREATE_DATA_PACKAGE
COLLECT_META_DATA META DATA

LINE_DELAY 0
MONITOR_LIMITS
PAUSE_ON_RED
{% endhighlight %}

* * *

## Table Manager Configuration

Table definition files define the binary table format so the Table Manager tool knows how to create, load, and display the binary data file. Table definition files are expected to be placed in the config/tools/table_manager directory and have a .txt extension.

## Keywords:

### TABLEFILE

The TABLEFILE keyword specifies another file to open and process for table definitions

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>File Name</td>
<td>Name of the file. The file will be looked for in the directory of the current definition file.</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TABLEFILE "MCConfigurationTable_def.txt"
{% endhighlight %}

### TABLE

The TABLE keyword designates the start of a new table definition.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Name</td>
<td><span style="color: rgb(0,0,0);">Name of the table in double quotes. The name will appear on the GUI tab.</span></td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Description</td>
<td colspan="1"><span style="color: rgb(0,0,0);">Description of this table in double quotes. The description is used in mouseover popups and status line information.</span></td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Dimension</td>
<td colspan="1"><span style="color: rgb(0,0,0);">Indicates the table is a ONE_DIMENSIONAL table which is a two column table consisting of unique rows, or a TWO_DIMENSIONAL table with multiple columns and identical rows with unique values.</span></td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Endianness</td>
<td colspan="1"><span style="color: rgb(0,0,0);">Whether to packet the table data as BIG_ENDIAN or LITTLE_ENDIAN.</span></td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Identifier</td>
<td colspan="1"><span style="color: rgb(0,0,0);">A unique numerical Table ID.</span></td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TABLE "MC Configuration" "Memory Control Configuration Table" ONE_DIMENSIONAL BIG_ENDIAN 9
{% endhighlight %}

### PARAMETER

The PARAMETER keyword defines a table parameter in the current table.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Name</td>
<td>Name of this parameter in double quotes. Must be unique within this table.</td>
<td>Yes</td></tr>
<tr>
<td>Description</td>
<td>Description of this parameter in double quotes. The description is used in mouseover popups and status line information.</td>
<td>Yes</td></tr>
<tr>
<td>Data Type</td>
<td>Data Type of this parameter. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data (32 or 64 bit), STRING = ASCII string, BLOCK = Binary block of data</td>
<td>Yes</td></tr>
<tr>
<td>Bit Size</td>
<td>Bit size of this parameter. Must be greater than 0.</td>
<td>Yes</td></tr>
<tr>
<td>Display Type</td>
<td>Display Type of this parameter. Possible types: DEC = Decimal, HEX = Hex, STATE = States (must be given later), CHECK = Checkbox, STRING = Must be used for STRING data types, NONE = Must be used for BLOCK types. Appending a -U to the display type makes the field uneditable.</td>
<td>Yes</td></tr>
<tr>
<td>Minimum Value</td>
<td>Minimum allowed value for this parameter. For STRING data types this indicates the minimum number of characters.</td>
<td>Yes</td></tr>
<tr>
<td>Maximum Value</td>
<td>Maximum allowed value for this parameter. For STRING data types this indicates the maximum number of characters.</td>
<td>Yes</td></tr>
<tr>
<td>Default Value</td>
<td>Default value for this parameter</td>
<td>Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
PARAMETER "Throttle" "Seconds to wait" FLOAT 32 DEC 0 0x0FFFFFFFF 2
PARAMETER "Scrubbing" "Memory Scrubbing" UINT 8 CHECK 0 1 1
PARAMETER "Pad" "Pad" UINT 16 HEX-U 0 0 0
{% endhighlight %}

### STATE

The STATE keyword defines a key/value pair for the current table parameter (the one most recently defined). For example, you might define states for ON = 1 and OFF = 0. This allows the word ON to be used rather than the number 1 when setting the table parameter and allows for much greater clarity and less chance for user error.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Key</td>
<td>The named state key. This can also be a string enclosed in double quotes.</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Value</td>
<td colspan="1">Value the key translates into</td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
PARAMETER "Scrubbing" "Memory Scrubbing" UINT 8 STATE 0 1 1
  STATE DISABLE 0
  STATE ENABLE 1
{% endhighlight %}

### DEFAULT

The DEFAULT keyword defines the default values for a row in a TWO_DIMENSIONAL table. Therefore, the number of DEFAULT lines defines the number of rows in the table. If no values are given after the keyword, the default as defined in the PARAMETER(s) will apply.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>Value1</td>
<td>The default value for the first defined PARAMETER in the TWO_DIMENSIONAL table.</td>
<td>No</td></tr>
<tr>
<td colspan="1">Value2</td>
<td colspan="1">The default value for the second defined PARAMETER in the TWO_DIMENSIONAL table.</td>
<td colspan="1">No</td></tr>
<tr>
<td colspan="1">ValueN</td>
<td colspan="1">The default value for the last defined PARAMETER in the TWO_DIMENSIONAL table.</td>
<td colspan="1">No</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
TABLE "TLM Monitoring" "Telemetry Monitoring Table" TWO_DIMENSIONAL BIG_ENDIAN 4
  PARAMETER "Threshold" "Telemetry item threshold at which point persistance is incremented" UINT 32 HEX 0 4294967295 0
  PARAMETER "Offset" "Offset into the telemetry packet to monitor" UINT 32 DEC 0 4294967295 0
  PARAMETER "Data Size" "Amount of data to monitor (bytes)" UINT 32 STATE 0 3 0
    STATE BITS 0
    STATE BYTE 1
    STATE WORD 2

DEFAULT             # Defaults of 0, 0, 0(BITS) will be used
DEFAULT 0x2         # Override Threshold default of 0
DEFAULT 0x3 30 WORD # Note the use of STATE names
{% endhighlight %}

### POLY_WRITE_CONVERSION

The POLY_WRITE_CONVERSION keyword adds a polynomial conversion factor to the current table parameter (the one most recently defined). This conversion factor is applied to the value entered by the user before it is written into the binary table file. All parameters with a POLY_WRITE_CONVERSION must also have a POLY_READ_CONVERSION. This read conversion should be the inverse function of the write conversion or the value might be inadvertently changed every time it is loaded and saved.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Required</th></tr>
<tr>
<td>C0</td>
<td>Coefficient #0.</td>
<td>Yes</td></tr>
<tr>
<td colspan="1">Cx</td>
<td colspan="1">Coefficient #x. This is the final coefficient value for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate.</td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
POLY_WRITE_CONVERSION 1 2 # 2x + 1 when writing to the table binary
POLY_READ_CONVERSION -0.5 0.5 # 0.5x - 0.5 when reading from the table binary
{% endhighlight %}

### POLY_READ_CONVERSION

The POLY_READ_CONVERSION keyword adds a polynomial conversion factor to the current table parameter (the one most recently defined). This conversion factor is applied to a table parameter read from the binary table file before it is displayed. Read conversions can be applied independently to read-only table parameters. If a table parameter is writable it must have both a read and write conversion.

<table>
<tbody>
<tr>
<th>Parameter</th>
<th>Description</th>
<th colspan="1">Required</th></tr>
<tr>
<td>C0</td>
<td>Coefficient #0.</td>
<td colspan="1">Yes</td></tr>
<tr>
<td colspan="1">Cx</td>
<td colspan="1">Coefficient #x. This is the final coefficient value for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate.</td>
<td colspan="1">Yes</td></tr></tbody></table>

Example Usage:
{% highlight bash %}
POLY_WRITE_CONVERSION -0.5 0.25 # 0.25x - 0.5 when writing to the table binary
POLY_READ_CONVERSION 2 4 # 2x + 4 when reading from the table binary
{% endhighlight %}

### GENERIC_WRITE_CONVERSION_START / GENERIC_WRITE_CONVERSION_END

### GENERIC_READ_CONVERSION_START / GENERIC_READ_CONVERSION_END

The generic conversion keywords add generic conversion functions to the current table parameter (the one most recently defined). This conversion factor is applied to the value entered by the user before it is written into the binary table file (for WRITE) and after it is read from the binary (for READ). The conversion is specified as ruby code that receives two implied parameters: 'value' which is the raw table parameter, and 'myself' which is a reference to the TableManager class. The last line of ruby code given should return the converted value. The conversion END keywords specify that all lines of ruby code for the conversion have been given. If a generic write conversion is created a generic read conversion must also be created. This read conversion should be the inverse of the write conversion or the value might be inadvertently changed every time it is loaded and saved.

Example Usage:
{% highlight bash %}
GENERIC_WRITE_CONVERSION_START
  value / 2
GENERIC_WRITE_CONVERSION_END
GENERIC_READ_CONVERSION_START
  value * 2
GENERIC_READ_CONVERSION_END
{% endhighlight %}

### CONSTRAINT_START / CONSTRAINT_END

The constraint keyword allows the user to modify the current parameter's allowable value range, default value, and/or conversion based on the value of another parameter.

Example Usage:
{% highlight bash %}
TABLE "Mechanism Control" "Description" ONE_DIMENSIONAL BIG_ENDIAN 1
  PARAMETER "Total Steps" "Total number of steps" UINT 16 HEX-U 0 2000 0
    CONSTRAINT_START
      if myself.get_table("Mechanism Control").get_packet_item("Other Param") == "OLD"
        value.range = 0..1.0\n")
        value.default = 1.0
      end
    CONSTRAINT_END
  PARAMETER "Other Param" "Yet another" INT 32 STATE -100 100 10
    STATE "OLD" 0
    STATE "NEW" 1
{% endhighlight %}

## Example File

**Example File: <COSMOSPATH>/config/table_manager/metable_def.txt**

{% highlight bash %}
TABLE "Mechanism Control" "Mechanism Control Table" ONE_DIMENSIONAL BIG_ENDIAN 1
  PARAMETER "Total Steps" "Total number of steps" UINT 16 HEX-U 0 2000 0
    CONSTRAINT_START
      if myself.get_table("Mechanism Control").get_packet_item("Other Param") == "OLD"
        value.range = 0..1.0\n")
        value.default = 1.0
      end
    CONSTRAINT_END
    POLY_READ_CONVERSION 1 2
    POLY_WRITE_CONVERSION 2 3
  PARAMETER "My Param" "Description" UINT 16 HEX-U 0 2000 0
    GENERIC_READ_CONVERSION_START
      value * 2
    GENERIC_READ_CONVERSION_END
    GENERIC_WRITE_CONVERSION_START
      value / 2
    GENERIC_WRITE_CONVERSION_END
  PARAMETER "Other Param" "Yet another" INT 32 STATE -100 100 10
    STATE "OLD" 0
    STATE "NEW" 1
  PARAMETER "Next Param" "Another param" FLOAT 64 STATE -Float::MAX Float::MAX 0.0
    STATE OFF 0.0
    STATE ON  1.0
  PARAMETER "String Param" "This is a string" STRING 32 STRING 2 4 "TEST"
  PARAMETER "Block Param" "Raw data" BLOCK 64 NONE 0 0 0xAAAA5555AAAA5555

TABLE "Event Action" "Event Action Table" TWO_DIMENSIONAL LITTLE_ENDIAN 2
  PARAMETER "Event" "The event" UINT 16 HEX 0 65535
  PARAMETER "Action" "The action" INT 32 STATE 1 2
    STATE OLD 1
    STATE NEW 2
  DEFAULT 0 OLD
  DEFAULT 0x100 2
  DEFAULT 1000 NEW
{% endhighlight %}
