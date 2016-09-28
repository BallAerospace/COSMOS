---
layout: docs
title: Scripting Guide
permalink: /docs/scripting/
---

<div class="toc">
{% capture toc %}{% include scripting_toc.md %}{% endcapture %}
{{ toc | markdownify }}
</div>

This document provides the information necessary to write test procedures using the COSMOS scripting API. Scripting in COSMOS is designed to be simple and intuitive. The code completion ability for command and telemetry mnemonics makes Script Runner the ideal place to write your procedures, however any text editor will do. If there is functionality that you don't see here or perhaps an easier syntax for doing something, please submit a ticket.

## Concepts

### Ruby Programming Language

COSMOS scripting is implemented using the Ruby Programming language. This should be largely transparent to the user, but if advanced processing needs to be done such as writing files, then knowledge of Ruby is necessary. Please see the Ruby Guide for more information about Ruby.

A basic summary of Ruby:

1. There is no 80 character limit on line length. Lines can be as long as you like, but be careful to not make them too long as it makes printed reviews of scripts more difficult.
1. Variables do not have to be declared ahead of time and can be reassigned later, i.e. Ruby is dynamically typed.
1. Variable values can be placed into strings using the "#{variable}" syntax. This is called variable interpolation.
1. A variable declared inside of a block or loop will not exist outside of that block unless it was already declared (see Ruby's variable scoping for more information).

The Ruby programming language provides a script writer a lot of power. But with great power comes great responsibility. Remember when writing your scripts that you or someone else will come along later and need to understand them. Therefore use the following style guidelines:

* Use two spaces for indentation and do NOT use tabs
* Constants should be all caps with underscores
    * ``` SPEED_OF_LIGHT = 299792458 # meters per s ```
* Variable names and method names should be in lowercase with underscores
    * ``` last_name = "Smith" ```
    * ``` perform_setup_operation() ```
* Class names (when used) should be camel case and the files which contain them should match but be lowercase with underscores
    * ``` class DataUploader # in 'data_uploader.rb' ```
    * ``` class CcsdsUtility # in 'ccsds_utility.rb' ```
* Don't add useless comments but instead describe intent

<div style="clear:both;"></div>

The following is an example of good style:
{% highlight ruby %}
Example Code
######################################
# Title block which describes the test
# Author: John Doe
# Date: 7/27/2007
######################################

load 'upload_utility.rb' # library we don't want to show executing
require_utility 'helper_utility' # library we do want to show executing

# Declare constants
OUR_TARGETS = ['INST','INST2']

# Clear the collect counter of the passed in target name
def clear_collects(target)
  cmd("#{target} CLEAR")
  wait_check("#{target} HEALTH_STATUS COLLECTS == 0", 5)
end

######################################
# START
######################################
helper = HelperUtility.new
helper.setup

# Perform collects on all the targets
OUR_TARGETS.each do |target|
  collects = tlm("#{target} HEALTH_STATUS COLLECTS")
  cmd("#{target} COLLECT with TYPE SPECIAL")
  wait_check("#{target} HEALTH_STATUS COLLECTS == #{collects + 1}", 5)
end

clear_collects('INST')
clear_collects('INST2')
{% endhighlight %}

This example shows several features of COSMOS scripting in action. Notice the difference between 'load' and 'require_utility'. The first is to load additional scripts which will NOT be shown in Script Runner when executing. This is a good place to put code which takes a long time to run such as image analysis or other looping code where you just want the output. 'require_utility' will visually execute the code line by line to show the user what is happening.

Next we declare our constants and create an array of strings which we store in OUR_TARGETS. Notice the constant is all uppercase with underscores.

Then we declare our local methods of which we have one called clear_collects. Please provide a comment at the beginning of each method describing what it does and the parameters that it takes.

The 'helper_utility' is then created by HelperUtility.new. Note the similarity in the class name and the file name we required.

The collect example shows how you can iterate over the array of strings we previously created and use variables when commanding and checking telemetry. The pound bracket #{} notation puts whatever the variable holds inside the #{} into the string. You can even execute additional code inside the #{} like we do when checking for the collect count to increment.

Finally we call our clear_collects method on each target by passing the target name. You'll notice there we used single quotes instead of double quotes. The only difference is that double quotes allow for the #{} syntax and support escape characters like newlines (\n) while single quotes do not. Otherwise it's just a personal style preference.

### Telemetry Types

There are four different ways that telemetry values can be retrieved in COSMOS. The following chart explains their differences.

| Telemetry Type | Description |
|----------------|-------------|
|Raw|Raw telemetry is exactly as it is in the telemetry packet before any conversions. All telemetry items will have a raw value except for Derived telemetry points which have no real location in a packet. Requesting raw telemetry on a derived item will return nil.|
|Converted|Converted telemetry is raw telemetry that has gone through a conversion factor such as a state conversion or a polynomial conversion. If a telemetry item does not have a conversion defined, then converted telemetry will be the same as raw telemetry. This is the most common type of telemety used in scripts.|
|Formatted|Formatted telemetry is converted telemetry that has gone through a printf style conversion into a string. Formatted telemetry will always have a string representation. If no format string is defined for a telemetry point, then formatted telemetry will be the same as converted telemetry except represented as string.|
|Formatted with Units|Formatted with Units telemetry is the same as Formatted telemetry except that a space and the units of the telemetry item are appended to the end of the string. If no units are defined for a telemetry item then this type is the same as Formatted telemetry.|

## Writing Test Procedures

### Using Subroutines

Subroutines in COSMOS scripting are first class citizens. They can allow you to perform repetitive tasks without copying the same code multiple times and in multiple different test procedures. This reduces errors and makes your test procedures more maintainable. For example, if multiple test procedures need to turn on a power supply and check telemetry, they can both use a common subroutine. If a change needs to be made to how the power supply is turned on, then it only has to be done in one location and all test procedures reap the benefits. No need to worry about forgetting to update one. Additionally using subroutines allows your high level procedure to read very cleanly and makes it easier for others to review. See the Subroutine Example example.

## Example Test Procedures

### Subroutines

{% highlight ruby %}
# My Utility Procedure: program_utilities.rb
# Author: Bob

#################################################################
# Define helpful subroutines useful by multiple test procedures
#################################################################

# This subroutine will put the instrument into safe mode
def goto_safe_mode
  cmd("INST SAFE")
  wait_check("INST SOH MODE == 'SAFE'", 30)
  check("INST SOH VOLTS1 < 1.0")
  check("INST SOH TEMP1 > 20.0")
  puts("The instrument is in SAFE mode")
end

# This subroutine will put the instrument into run mode
def goto_run_mode
  cmd("INST RUN")
  wait_check("INST SOH MODE == 'RUN'", 30)
  check("INST SOH VOLTS1 > 27.0")
  check("INST SOH TEMP1 > 20.0")
  puts("The instrument is in RUN mode")
end

# This subroutine will turn on the power supply
def turn_on_power
  cmd("GSE POWERON")
  wait_check("GSE SOH VOLTAGE > 27.0")
  check("GSE SOH CURRENT < 2.0")
  puts("WARNING: Power supply is ON!")
end

# This subroutine will turn off the power supply
def turn_off_power
  cmd("GSE POWEROFF")
  wait_check("GSE SOH VOLTAGE < 1.0")
  check("GSE SOH CURRENT < 0.1")
  puts("Power supply is OFF")
end

# My Test Procedure: run_instrument.rb
# Author: Larry

require_utility("program_utilities.rb")

turn_on_power()
goto_run_mode()

# Perform unique tests here

goto_safe_mode()
turn_off_power()
{% endhighlight %}

### Ruby Control Structures

{% highlight ruby %}
#if, elsif, else structure

x = 3

if tlm("INST HEALTH_STATUS COLLECTS") > 5
  puts "More than 5 collects!"
elsif (x == 4)
  puts "variable equals 4!"
else
  puts "Nothing interesting going on"
end

#Endless loop and single-line if

loop do
  break if tlm("INST HEALTH_STATUS TEMP1") > 25.0
  wait(1)
end

#Do something a given number of times

5.times do
  cmd("INST COLLECT")
end
{% endhighlight %}

### Iterating over similarly named telemetry points

{% highlight ruby %}
#This block of code goes through the range of numbers 1 through 4 (1..4)
#and checks telemetry items TEMP1, TEMP2, TEMP3, and TEMP4

(1..4).each do |num|
  check("INST HEALTH_STATUS TEMP#{num} > 25.0")
end

#You could also do

num = 1
4.times do
  check("INST HEALTH_STATUS TEMP#{num} > 25.0")
  num = num + 1
end
{% endhighlight %}

### Prompting for User Input

{% highlight ruby %}
numloops = ask("Please enter the number of times to loop")

numloops.times do
  puts "Looping"
end
{% endhighlight %}

## Running Test Procedures

## Execution Environment

### Using Script Runner

Script Runner is a graphical application that provides the ideal environment for running and implementing your test procedures. The Script Runner tool is broken into 4 main sections. At the top of the tool is a menu bar that allows you to do such things as open and save files, comment out blocks of code, perform a syntax check, and execute your script.

Next is a tool bar that displays the currently executing line number of the script and three buttons, "Go", "Pause/Resume?", and "Stop". The Go button is used to skip wait statements within the script. This is sometimes useful if an excessive wait statement is added to a script. The Pause/Resume? button will pause the executing script and display the next line that will be executed. Resume will resume execution of the script. The Resume button is also used to continue script execution after an exception occurs such as trying to send a command with a parameter that is out of range. Finally, the Stop button will stop the executing script at any time.

Third is the display of the actual script. While the script is not running, you may edit and compose scripts in this area. A handy code completion feature is provided that will list out the available commands or telemetry points as you are writing your script. Simply begin writing a cmd( or tlm( line to bring up code completion. This feature greatly reduces typos in command and telemetry mnemonics.

Finally, displayed is the script output. All commands that are sent, errors that occur, and user puts statements appear in this output section. Additionally anything printed into this section is logged by Script Runner into your projects COSMOS user area.

### From the Command Line

Note that any COSMOS script can also be run from the command line if the script begins with the following two lines:
{% highlight ruby %}
require 'cosmos'
require 'cosmos/script'
{% endhighlight %}

The Script Runner Tool automatically executes these lines for you so they aren't required for scripts that will only be run from Script Runner. Nice features such as display of the current line or the ability to pause a script are not available from the command line.

## Test Procedure API

The following methods are designed to be used in test procedures. However, they can also be used in custom built COSMOS tools. Please see the COSMOS Tool API section for methods that are more efficient to use in custom tools.

## Retrieving User Input

These methods allow the user to enter values that are needed by the script.

### ask

The ask method prompts the user for input with a question. User input is automatically converted from a string to the appropriate data type. For example if the user enters "1", the number 1 as an integer will be returned.

Syntax:
```ask("<question>")```

| Parameter | Description |
| -------- | --------------------------------- |
| question | Question to prompt the user with. |
| blank_or_default | Whether or not to allow empty responses (optional - defaults to false). If a non-boolean value is passed it is used as a default value. |
| password | Whether to treat the entry as a password which is displayed with dots and not logged. |

Example:
{% highlight ruby %}
value = ask("Enter an integer")
value = ask("Enter a value or nothing", true)
value = ask("Enter a value", 10)
password = ask("Enter your password", false, true)
{% endhighlight %}

### ask_string

The ask_string method prompts the user for input with a question. User input is always returned as a string. For exampe if the user enters "1", the string "1" will be returned.

Syntax:
```ask_string("<question>")```

| Parameter | Description |
| -------- | --------------------------------- |
| question | Question to prompt the user with.|
| blank_or_default | Whether or not to allow empty responses (optional - defaults to false). If a non-boolean value is passed it is used as a default value. |
| password | Whether to treat the entry as a password which is displayed with dots and not logged. |

Example:
{% highlight ruby %}
string = ask_string("Enter a String")
string = ask_string("Enter a value or nothing", true)
string = ask_string("Enter a value", "test")
password = ask_string("Enter your password", false, true)
{% endhighlight %}

### message_box

### vertical_message_box

### combo_box

The message_box, vertical_message_box, and combo_box methods create a message box with arbitrary buttons or selections that the user can click. The text of the button clicked is returned.

Syntax:

```
message_box("<message>", "<button text 1>", …)
message_box("<message>", "<button text 1>", …, false) # Since COSMOS 3.8.3
vertical_message_box("<message>", "<button text 1>", …) # Since COSMOS 3.5.0
vertical_message_box("<message>", "<button text 1>", …, false) # Since COSMOS 3.8.3
combo_box("<message>", "<selection text 1>", …) # Since COSMOS 3.5.0
combo_box("<message>", "<selection text 1>", …, false) # Since COSMOS 3.8.3
```

| Parameter | Description |
| -------- | --------------------------------- |
|message|Message to prompt the user with.|
|button/selection text|Text for a button or selection|
|false|Whether to display the "Cancel" button (since 3.8.3)|

Example:
{% highlight ruby %}
value = message_box("Select the sensor number", 'One', 'Two')
value = vertical_message_box("Select the sensor number", 'One', 'Two')
value = combo_box("Select the sensor number", 'One', 'Two')
case value
when 'One'
  puts 'Sensor One'
when 'Two'
  puts 'Sensor Two'
end
{% endhighlight %}

## Providing information to the user

These methods notify the user that something has occurred.

### prompt

The prompt method displays a message to the user and waits for them to press an ok button.

Syntax:
``` prompt("<message>") ```

| Parameter | Description |
| -------- | --------------------------------- |
|message|Message to prompt the user with.|

Example:
{% highlight ruby %}
prompt("Press OK to continue")
{% endhighlight %}

### status_bar

The status_bar method displays a message to the user in the status bar (at the bottom of the tool).

Syntax:
``` status_bar("<message>") ```

| Parameter | Description |
| -------- | --------------------------------- |
|message|Message to display in the status bar|

Example:
{% highlight ruby %}
status_bar("Connection Successful")
{% endhighlight %}

### play_wav_file

The play_wav_file method plays the provided wav file once.  Note that the script will proceed while the wav file plays.

Syntax:
``` play_wav_file(wav_filename) ```

| Parameter | Description |
| -------- | --------------------------------- |
|wav_filename|Path and filename of the wav file to play.|

Example:
{% highlight ruby %}
play_wav_file("config/data/alarm.wav")
{% endhighlight %}

## Commands

These methods provide capability to send commands to a target and receive information about commands in the system.

### cmd

The cmd method sends a specified command.

Syntax:
{% highlight ruby %}
cmd("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd("<Target Name>", "<Command Name>", "Param #1 Name" => <Param #1 Value>, "Param #2 Name" => <Param #2 Value>, ...)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd("INST COLLECT with DURATION 10, TYPE NORMAL")
cmd("INST", "COLLECT", "DURATION" => 10, "TYPE" => "NORMAL")
{% endhighlight %}

### cmd_no_range_check

The cmd_no_range_check method sends a specified command without performing range checking on its parameters. This should only be used when it is necessary to intentionally send a bad command parameter to test a target.

Syntax:
{% highlight ruby %}
cmd_no_range_check("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_no_range_check("<Target Name>", "<Command Name>", "Param #1 Name" => <Param #1 Value>, "Param #2 Name" => <Param #2 Value>, ...)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_no_range_check("INST COLLECT with DURATION 11, TYPE NORMAL")
cmd_no_range_check("INST", "COLLECT", "DURATION" => 11, "TYPE" => "NORMAL")
{% endhighlight %}

### cmd_no_hazardous_check

The cmd_no_hazardous_check method sends a specified command without performing the notification if it is a hazardous command. This should only be used when it is necessary to fully automate testing involving hazardous commands.

Syntax:
{% highlight ruby %}
cmd_no_hazardous_check("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_no_hazardous_check("<Target Name>", "<Command Name>", "Param #1 Name" => <Param #1 Value>, "Param #2 Name" => <Param #2 Value>, ...)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_no_hazardous_check("INST CLEAR")
cmd_no_hazardous_check("INST", "CLEAR")
{% endhighlight %}

### cmd_no_checks

The cmd_no_checks method sends a specified command without performing the parameter range checks or notification if it is a hazardous command. This should only be used when it is necessary to fully automate testing involving hazardous commands that intentially have invalid parameters.

Syntax:
{% highlight ruby %}
cmd_no_checks("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_no_checks("<Target Name>", "<Command Name>", "Param #1 Name" => <Param #1 Value>, "Param #2 Name" => <Param #2 Value>, ...)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_no_checks("INST COLLECT with DURATION 11, TYPE SPECIAL")
cmd_no_checks("INST", "COLLECT", "DURATION" => 11, "TYPE" => "SPECIAL")
{% endhighlight %}

### cmd_raw

The cmd_raw method sends a specified command without running conversions.

Syntax:
{% highlight ruby %}
cmd_raw("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_raw("<Target Name>", "<Command Name>", "<Param #1 Name>" => <Param #1 Value>, "<Param #2 Name>" => <Param #2 Value>, …)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_raw("INST COLLECT with DURATION 10, TYPE 0")
cmd_raw("INST", "COLLECT", "DURATION" => 10, TYPE => 0)
{% endhighlight %}

### cmd_raw_no_range_check

The cmd_raw_no_range_check method sends a specified command without running conversions or performing range checking on its parameters. This should only be used when it is necessary to intentionally send a bad command parameter to test a target.

Syntax:
{% highlight ruby %}
cmd_raw_no_range_check("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_raw_no_range_check("<Target Name>", "<Command Name>", "<Param #1 Name>" => <Param #1 Value>, "<Param #2 Name>" => <Param #2 Value>, …)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_raw_no_range_check("INST COLLECT with DURATION 11, TYPE 0")
cmd_raw_no_range_check("INST", "COLLECT", "DURATION" => 11, "TYPE" => 0)
{% endhighlight %}

### cmd_raw_no_hazardous_check

The cmd_raw_no_hazardous_check method sends a specified command without running conversions or performing the notification if it is a hazardous command. This should only be used when it is necessary to fully automate testing involving hazardous commands.

Syntax:
{% highlight ruby %}
cmd_raw_no_hazardous_check("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_raw_no_hazardous_check("<Target Name>", "<Command Name>", "<Param #1 Name>" => <Param #1 Value>, "<Param #2 Name>" => <Param #2 Value>, …)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_raw_no_hazardous_check("INST CLEAR")
cmd_raw_no_hazardous_check("INST", "CLEAR")
{% endhighlight %}

### cmd_raw_no_checks

The cmd_raw_no_checks method sends a specified command without running conversions or performing the parameter range checks or notification if it is a hazardous command. This should only be used when it is necessary to fully automate testing involving hazardous commands that intentially have invalid parameters.

Syntax:
{% highlight ruby %}
cmd_raw_no_checks("<Target Name> <Command Name> with <Param #1 Name> <Param #1 Value>, <Param #2 Name> <Param #2 Value>, …")
cmd_raw_no_checks("<Target Name>", "<Command Name>", "<Param #1 Name>" => <Param #1 Value>, "<Param #2 Name>" => <Param #2 Value>, …)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target this command is associated with. |
| Command Name | Name of this command. Also referred to as its mnemonic. |
| Param #x Name | Name of a command parameter. If there are no parameters then the 'with' keyword should not be given. |
| Param #x Value | Value of the command parameter. Values are automatically converted to the appropriate type. |

Example:
{% highlight ruby %}
cmd_raw_no_checks("INST COLLECT with DURATION 11, TYPE 1")
cmd_raw_no_checks("INST", "COLLECT", "DURATION" => 11, "TYPE" => 1)
{% endhighlight %}

### send_raw

The send_raw method sends raw data on an interface.

Syntax:
``` send_raw(<Interface Name>, <data>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the interface to send the raw data on. |
|Data | Raw ruby string of data to send. |

Example:
{% highlight ruby %}
send_raw("INST1INT", data)
{% endhighlight %}

### send_raw_file

The send_raw_file method sends raw data on an interface from a file.

Syntax:
``` send_raw_file(<Interface Name>, <filename>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the interface to send the raw data on. |
| filename | Full path to the file with the data to send. |

Example:
{% highlight ruby %}
send_raw_file("INST1INT", "/home/user/data_to_send.bin")
{% endhighlight %}

### get_cmd_list

The get_cmd_list method returns an array of the commands that are available for a particular target.  The returned array is an array of array swhere each subarray contains the command name and description.

Syntax:
``` get_cmd_list("<Target Name>") ```


| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |

Example:
{% highlight ruby %}
cmd_list = get_cmd_list("INST")
puts cmd_list.inspect # [['TARGET_NAME', 'DESCRIPTION'], ...]
{% endhighlight %}

### get_cmd_param_list

The get_cmd_param_list method returns an array of the command parameters that are available for a particular command.   The returned array is an array of arrays where each subarray contains [parameter_name, default_value, states_hash, description, units_full, units, required_flag]

Syntax:
``` get_cmd_param_list("<Target Name>", "<Command Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Command Name | Name of the command. |

Example:
{% highlight ruby %}
cmd_param_list = get_cmd_param_list("INST", "COLLECT")
puts cmd_param_list.inspect # [["CCSDSVER", 0, nil, "CCSDS primary header version number", nil, nil, false], ...]
{% endhighlight %}

### get_cmd_hazardous

The get_cmd_hazardous method returns true/false indicating whether a particular command is flagged as hazardous.

Syntax:
{% highlight ruby %}
get_cmd_hazardous("<Target Name>", "<Command Name>", <Command Params - optional>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Command Name | Name of the command. |
| Command Params | Hash of the parameters given to the command (optional). Note that some commands are only hazardous based on parameter states. |

Example:
{% highlight ruby %}
hazardous = get_cmd_hazardous("INST", "COLLECT", {'TYPE' => 'SPECIAL'})
{% endhighlight %}

### get_cmd_value

The get_cmd_value method returns reads a value from the most recently sent command packet.   The pseudo-parameters 'RECEIVED_COUNT', 'RECEIVED_TIMEFORMATTED', and 'RECEIVED_TIMESECONDS' are also supported.

Syntax:
{% highlight ruby %}
get_cmd_value("<Target Name>", "<Command Name>", "<Parameter Name>", <Value Type - optional>) # Since COSMOS 3.5.0
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Command Name | Name of the command. |
| Parameter Name | Name of the command parameter. |
| Value Type | Value Type to read. :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS |

Example:
{% highlight ruby %}
value = get_cmd_value("INST", "COLLECT", "TEMP")
{% endhighlight %}

### get_cmd_time

The get_cmd_time method returns the time of the most recent command sent.

Syntax:
{% highlight ruby %}
get_cmd_time("<Target Name - optional>", "<Command Name - optional>") # Since COSMOS 3.5.0
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target.  If not given, then the most recent command time to any target will be returned |
| Command Name | Name of the command.  If not given, then the most recent command time to the given target will be returned |

Example:
{% highlight ruby %}
target_name, command_name, time = get_cmd_time() # Name of the most recent command sent to any target and time
target_name, command_name, time = get_cmd_time("INST") # Name of the most recent command sent to the INST target and time
target_name, command_name, time = get_cmd_time("INST", "COLLECT") # Name of the most recent INST COLLECT command and time
{% endhighlight %}

## Handling Telemetry

These methods allow the user to interact with telemetry items.

### check
The check method performs a verification of a telemetry item using its converted telemetry type. If the verification fails then the script will be paused with an error. If no comparision is given to check then the telemetry item is simply printed to the script output.   Note: In most cases using wait_check is a better choice than using check.

Syntax:
{% highlight ruby %}
check("<Target Name> <Packet Name> <Item Name> <Comparison - optional>")
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. If a comparison is not given then the telemetry item will just be printed into the script log. |

Example:
{% highlight ruby %}
check("INST HEALTH_STATUS COLLECTS > 1")
{% endhighlight %}

### check_raw

The check_raw method performs a verification of a telemetry item using its raw telemetry type. If the verification fails then the script will be paused with an error. If no comparision is given to check then the telemetry item is simply printed to the script output.  Note: In most cases using wait_check_raw is a better choice than using check_raw.

Syntax:
{% highlight ruby %}
check_raw("<Target Name> <Packet Name> <Item Name> <Comparison>")
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. If a comparison is not given then the telemetry item will just be printed into the script log. If a comparison is not given then the telemetry item will just be printed into the script log. |

Example:
{% highlight ruby %}
check_raw("INST HEALTH_STATUS COLLECTS > 1")
{% endhighlight %}

### check_formatted

The check_formatted method performs a verification of a telemetry item using its formatted telemetry type. If the verification fails then the script will be paused with an error. If no comparision is given to check then the telemetry item is simply printed to the script output.

Syntax:
{% highlight ruby %}
check_formatted("<Target Name> <Packet Name> <Item Name> <Comparison>")
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. If a comparison is not given then the telemetry item will just be printed into the script log. If a comparison is not given then the telemetry item will just be printed into the script log. |

Example:
{% highlight ruby %}
check_formatted("INST HEALTH_STATUS COLLECTS == '1'")
{% endhighlight %}

### check_with_units

The check_with_units method performs a verification of a telemetry item using its formatted with units telemetry type. If the verification fails then the script will be paused with an error. If no comparision is given to check then the telemetry item is simply printed to the script output.

Syntax:
{% highlight ruby %}
check_with_units("<Target Name> <Packet Name> <Item Name> <Comparison>")
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. If a comparison is not given then the telemetry item will just be printed into the script log. If a comparison is not given then the telemetry item will just be printed into the script log. |

Example:
{% highlight ruby %}
check_with_units("INST HEALTH_STATUS COLLECTS == '1'")
{% endhighlight %}

### check_tolerance

The check_tolerance method checks a converted telemetry item against an expected value with a tolerance. If the verification fails then the script will be paused with an error.  Note: In most cases using wait_check_tolerance is a better choice than using check_tolerance.

Syntax:
{% highlight ruby %}
check_tolerance("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |

Example:
{% highlight ruby %}
check_tolerance("INST HEALTH_STATUS COLLECTS", 10.0, 5.0)
{% endhighlight %}

### check_tolerance_raw

The check_tolerance_raw method checks a raw telemetry item against an expected value with a tolerance. If the verification fails then the script will be paused with an error.  Note: In most cases using wait_check_tolerance_raw is a better choice than using check_tolerance_raw.

Syntax:
{% highlight ruby %}
check_tolerance_raw("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |

Example:
{% highlight ruby %}
check_tolerance_raw("INST HEALTH_STATUS COLLECTS", 10.0, 5.0)
{% endhighlight %}

### check_expression

The check_expression method evaluates an expression. If the expression evaluates to false the script will be paused with an error. This method can be used to perform more complicated comparisons than using check as shown in the example.  Note: In most cases using [wait_check_expression](#waitcheckexpression) is a better choice than using check_expression.

Remember that everything inside the check_expression string will be evaluated directly by the Ruby interpreter and thus must be valid syntax. A common mistake is to check a variable like so:

```check_expression("#{answer} == 'yes'") # where answer contains 'yes' ```

This evaluates to ```yes == 'yes'``` which is not valid syntax because the variable yes is not defined (usually). The correct way to write this expression is as follows:

```check_expression("'#{answer}' == 'yes'") # where answer contains 'yes' ```

Now this evaluates to ```'yes' == 'yes'``` which is true so the check passes.

Syntax:
``` check_expression("<Expression>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Expression | A ruby expression to evaluate. |

Example:
{% highlight ruby %}
check_expression("tlm('INST HEALTH_STATUS COLLECTS') > 5 and tlm('INST HEALTH_STATUS TEMP1') > 25.0")
{% endhighlight %}

### tlm

The tlm method reads the converted form of a specified telemetry item.

Syntax:
``` tlm("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
value = tlm("INST HEALTH_STATUS COLLECTS")
{% endhighlight %}

### tlm_raw

The tlm_raw method reads the raw form of a specified telemetry item.

Syntax:
``` tlm_raw("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
value = tlm_raw("INST HEALTH_STATUS COLLECTS")
{% endhighlight %}

### tlm_formatted

The tlm_formatted method reads the formatted form of a specified telemetry item.

Syntax:
``` tlm_formatted("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
value = tlm_formatted("INST HEALTH_STATUS COLLECTS")
{% endhighlight %}

### tlm_with_units

The tlm_with_units method reads the formatted with units form of a specified telemetry item.

Syntax:
``` tlm_with_units("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
value = tlm_with_units("INST HEALTH_STATUS COLLECTS")
{% endhighlight %}

### tlm_variable

The tlm_variable method reads a specified telemetry item with a variable value type.

Syntax:
``` tlm_variable("<Target Name> <Packet Name> <Item Name>", <Value Type>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Value Type | Value Type to read. :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS |

Example:
{% highlight ruby %}
value = tlm_variable("INST HEALTH_STATUS COLLECTS", :RAW)
{% endhighlight %}

### get_tlm_packet

The get_tlm_packet method returns the names, values, and limits states of all telemetry items in a specified packet.    The value is returned as an array of arrays with each entry containing [item_name, item_value, limits_state].

Syntax:
``` get_tlm_packet("<Target Name>", "<Packet Name>", value_type) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Packet Name | Name of the packet. |
| value_type | Telemetry Type to read the values in. :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS. Defaults to :CONVERTED |

Example:
{% highlight ruby %}
names_values_and_limits_states = get_tlm_packet("INST", "HEALTH_STATUS", :FORMATTED)
{% endhighlight %}

### get_tlm_values

The get_tlm_values method returns the values, limits_states, limits_settings, and current limits_set for a specified set of telemetry items. Items can be in any telemetry packet in the system. They can all be retrieved using the same value type or a specific value type can be specified for each item.

Syntax:
{% highlight ruby %}
values, limits_states, limits_settings, limits_set = get_tlm_values(<items>, <value_types>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| items | Array of item arrays of the form [[Target Name #1, Packet Name #1, Item Name #1], … ] |
| value_types | Telemetry Type to read the values in. :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS. Defaults to :CONVERTED . May be specified as a single symbol that applies to all items or an array of symbols, one for each item. |

Example:
{% highlight ruby %}
values, limits_states, limits_settings, limits_set = get_tlm_values([[INST", "ADCS", "Q1"], ["INST", "ADCS", "Q2"]], [:FORMATTED, :WITH_UNITS])
{% endhighlight %}

### get_tlm_list

The get_tlm_list method returns an array of the telemetry packets and their descriptions that are available for a particular target.

Syntax:
{% highlight ruby %}
packet_names_and_descriptions = get_tlm_pkt_list("<Target Name>")
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |

Example:
{% highlight ruby %}
packet_names_and_descriptions = = get_tlm_list("INST")
{% endhighlight %}

### get_tlm_item_list

The get_tlm_item_list method returns an array of the telemetry items that are available for a particular telemetry packet.  The returned value is an array of arrays where each subarray contains [item_name, item_states_hash, description]

Syntax:
``` get_tlm_item_list("<Target Name>", "<Packet Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Packet Name | Name of the telemetry packet. |

Example:
{% highlight ruby %}
item_names_states_and_descriptions = get_tlm_item_list("INST", "HEALTH_STATUS")
{% endhighlight %}

### get_tlm_details

The get_tlm_details method returns an array with details about the specified telemetry items such as their limits and states.

Syntax:
``` get_tlm_item_details(<items>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| items | Array of item arrays of the form [[Target Name #1, Packet Name #1, Item Name #1], … ] |

Example:
{% highlight ruby %}
details = get_tlm_item_details("INST", "HEALTH_STATUS", "COLLECTS")
{% endhighlight %}

### set_tlm

The set_tlm method sets a telemetry item value in the Command and Telemetry Server. This value will be overwritten if a new packet is received from an interface.  For that reason this method is most useful if interfaces are disconnected or for testing via the Script Runner disconnect mode. (Note that in disconnect mode it will only set telemetry within ScriptRunner. Other tools like TlmViewer will not reflect any changes) Manually setting telemetry values allows for the execution of many logical paths in scripts.

Syntax:
``` set_tlm("<Target> <Packet> <Item> = <Value>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target | Target name |
| Packet | Packet name |
| Item | Item name |
| Value | Value to set |

Example:
{% highlight ruby %}
set_tlm("INST HEALTH_STATUS COLLECTS = 5")
check("INST HEALTH_STATUS COLLECTS == 5") # This will pass since we just set it to 5
{% endhighlight %}

### set_tlm_raw

The set_tlm_raw method sets a raw telemetry item value in the Command and Telemetry Server. This value will be overwritten if a new packet is received from an interface.  For that reason this method is most useful if interfaces are disconnected or for testing via the Script Runner disconnect mode. (Note that in disconnect mode it will only set telemetry within ScriptRunner. Other tools like TlmViewer will not reflect any changes) Manually setting telemetry values allows for the execution of many logical paths in scripts.

Syntax:
``` set_tlm_raw("<Target> <Packet> <Item> = <Value>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target | Target name |
| Packet | Packet name |
| Item | Item name |
| Value | Value to set |

Example:
{% highlight ruby %}
# Assuming TEMP1 is defined with a conversion (as it is in the COSMOS demo)
set_tlm("INST HEALTH_STATUS TEMP1 = 5")
check_tolerance("INST HEALTH_STATUS TEMP1", 5, 0.5) # Pass
set_tlm_raw("INST HEALTH_STATUS TEMP1 = 5")
check_tolerance("INST HEALTH_STATUS TEMP1", 5, 0.5) # Fail because we set the raw value not the converted value
{% endhighlight %}

## Packet Data Subscriptions

Methods for subscribing to specific packets of data. This provides an interface to ensure that each telemetry packet is received and handled rather than relying on polling where some data may be missed.

### subscribe_packet_data

 The subscribe_packet_data method allows the user to listen for one or more telemetry packets of data to arrive. A unique id is returned to the tool which is used to retrieve the data. The subscribed packets are placed into a queue where they can then be processed one at a time.

Syntax:
``` subscribe_packet_data(packets, queue_size) ```

| Parameter | Description |
| -------- | --------------------------------- |
| packets | Nested array of target name/packet name pairs that the user wishes to subscribe to. |
| queue_size | Number of packets to let queue up before dropping the connection. Defaults to 1000. |

Example:
{% highlight ruby %}
id = subscribe_packet_data([['INST', 'HEALTH_STATUS'], ['INST', 'ADCS']], 2000)
{% endhighlight %}

### unsubscribe_packet_data

 The unsubscribe_packet_data method allows the user to stop listening for packet_data. This should be called to reduce the server's load if the subscription is no longer needed.

Syntax:
``` unsubscribe_packet_data(id) ```

| Parameter | Description |
| -------- | --------------------------------- |
| id | Unique id given to the tool by subscribe_packet_data. |

Example:
{% highlight ruby %}
unsubscribe_packet_data(id)
{% endhighlight %}

### get_packet

Receives a subscribed telemetry packet. If get_packet is called non-blocking <non_block> = true, get_packet will raise an error if the queue is empty.

Syntax:
``` get_packet(id, non_block (optional)) ```

| Parameter | Description |
| -------- | --------------------------------- |
| id | Unique id given to the tool by subscribe_packet_data. |
| non_block | Boolean to indicate if the method should block until an packet of data is received or not. Defaults to false, blocks reading data from queue. |

Example:
{% highlight ruby %}
packet = get_packet(id)
value = packet.read('ITEM_NAME')
{% endhighlight %}

### get_packet_data

NOTE:  Most users will want to use get_packet() instead of this lower level method.  The get_packet_data method returns a ruby string containing the packet data from a specified telemetry packet. It also returns which telemetry packet the data is from. Can be run in a non-blocking or blocking manner. Packets are queued after calling subscribe_packet_data and none will be lost. If 1000 (or whatever queue_size was specified in subscribe_packet_data) packets are queued and get_packet_data has not been called or has not been keeping up, then the subscription will be dropped.

The returned packet data can be used to populate a packet object. A packet object can be obtained from the System object.

If get_packet_data is called non-blocking <non_block> = true, get_packet_data will raise an error if the queue is empty.

Syntax:
``` get_packet_data(id, non_block) ```

| Parameter | Description |
| -------- | --------------------------------- |
| id | Unique id given to the tool by subscribe_packet_data. |
| non_block | Boolean to indicate if the method should block until an packet of data is received or not. Defaults to false, blocks reading data from queue. |

Example:
{% highlight ruby %}
id = subscribe_packet_data([[“TGT, “PKT1”], [“TGT”, “PKT2”]]) # note double nested array

buffer, target_name, packet_name, received_time, received_count = get_packet_data(id)
packet = System.telemetry.packet(target_name, packet_name).clone
packet.buffer = buffer
packet.received_time = received_time
packet.received_count = received_count
{% endhighlight %}

## Delays

These methods allow the user to pause the script to wait for telemetry to change or for an amount of time to pass.

### wait

The wait method pauses the script for a configurable amount of time or until a converted telemetry item meets given criteria. It supports three different syntaxes as shown. If no parameters are given then an infinite wait occurs until the user presses Go.   Note that on a timeout, wait does not stop the script, usually wait_check is a better choice.

Syntax:
{% highlight ruby %}
wait()
wait(<Time>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Time | Time in Seconds to delay for. |

{% highlight ruby %}
wait("<Target Name> <Packet Name> <Item Name> <Comparison>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. |
| Timeout | Timeout in seconds. Script will proceed if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait()
wait(5)
wait("INST HEALTH_STATUS COLLECTS == 3", 10)
{% endhighlight %}

### wait_raw

The wait_raw method pauses the script for a configurable amount of time or until a raw telemetry item meets given criteria. It supports two different syntaxes as shown. If no parameters are given then an infinite wait occurs until the user presses Go.  Note that on a timeout, wait_raw does not stop the script, usually wait_check_raw is a better choice.

Syntax:
``` wait_raw(<Time>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Time | Time in Seconds to delay for. |

{% highlight ruby %}
wait_raw("<Target Name> <Packet Name> <Item Name> <Comparison>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. |
| Timeout | Timeout in seconds. Script will proceed if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait_raw(5)
wait_raw("INST HEALTH_STATUS COLLECTS == 3", 10)
{% endhighlight %}

### wait_tolerance

The wait_tolerance method pauses the script for a configurable amount of time or until a converted telemetry item meets equals an expected value within a tolerance.  Note that on a timeout, wait_tolerance does not stop the script, usually wait_check_tolerance is a better choice.

Syntax:
{% highlight ruby %}
wait_tolerance("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |
| Timeout | Timeout in seconds. Script will proceed if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait_tolerance("INST HEALTH_STATUS COLLECTS", 10.0, 5.0, 10)
{% endhighlight %}

### wait_tolerance_raw

The wait_tolerance_raw method pauses the script for a configurable amount of time or until a raw telemetry item meets equals an expected value within a tolerance.  Note that on a timeout, wait_tolerance_raw does not stop the script, usually wait_check_tolerance_raw is a better choice.

Syntax:
{% highlight ruby %}
wait_tolerance_raw("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |
| Timeout | Timeout in seconds. Script will proceed if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait_tolerance_raw("INST HEALTH_STATUS COLLECTS", 10.0, 5.0, 10)
{% endhighlight %}

### wait_expression

The wait_expression method pauses the script until an expression is evaluated to be true or a timeout occurs. If a timeout occurs the script will continue. This method can be used to perform more complicated comparisons than using wait as shown in the example.  Note that on a timeout, wait_expression does not stop the script, usually [wait_check_expression](#waitcheckexpression) is a better choice.

Syntax:
{% highlight ruby %}
wait_expression("<Expression>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Expression | A ruby expression to evaluate. |
| Timeout | Timeout in seconds. Script will proceed if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_expression("tlm('INST HEALTH_STATUS COLLECTS') > 5 and tlm('INST HEALTH_STATUS TEMP1') > 25.0", 10)
{% endhighlight %}

### wait_packet

The wait_packet method pauses the script until a certain number of packets have been received. If a timeout occurs the script will continue.   Note that on a timeout, wait_packet does not stop the script, usually wait_check_packet is a better choice.

Syntax:
{% highlight ruby %}
wait_packet("<Target>", "<Packet>", <Num Packets>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target | The target name |
| Packet | The packet name |
| Num Packets | The number of packets to receive |
| Timeout | Timeout in seconds. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_packet('INST', 'HEALTH_STATUS', 5, 10) # Wait for 5 INST HEALTH_STATUS packets over 10s
{% endhighlight %}

### wait_check

The wait_check method combines the wait and check keywords into one. This pauses the script until the converted value of a telemetry item meets given criteria or times out. On a timeout the script stops.

Syntax:
{% highlight ruby %}
wait_check("<Target Name> <Packet Name> <Item Name> <Comparison>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_check("INST HEALTH_STATUS COLLECTS > 5", 10)
{% endhighlight %}

### wait_check_raw

The wait_check_raw method combines the wait_raw and check_raw keywords into one. This pauses the script until the raw value of a telemetry item meets given criteria or times out. On a timeout the script stops.

Syntax:
{% highlight ruby %}
wait_check_raw("<Target Name> <Packet Name> <Item Name> <Comparison>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Comparison | A comparison to perform against the telemetry item. |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_check_raw("INST HEALTH_STATUS COLLECTS > 5", 10)
{% endhighlight %}

### wait_check_tolerance

The wait_check_tolerance method pauses the script for a configurable amount of time or until a converted telemetry item equals an expected value within a tolerance. On a timeout the script stops.

Syntax:
{% highlight ruby %}
wait_check_tolerance("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait_check_tolerance("INST HEALTH_STATUS COLLECTS", 10.0, 5.0, 10)
{% endhighlight %}

### wait_check_tolerance_raw

The wait_check_tolerance_raw method pauses the script for a configurable amount of time or until a raw telemetry item meets equals an expected value within a tolerance. On a timeout the script stops.

Syntax:
{% highlight ruby %}
wait_check_tolerance_raw("<Target Name> <Packet Name> <Item Name>", <Expected Value>, <Tolerance>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Expected Value | Expected value of the telemetry item. |
| Tolerance | ± Tolerance on the expected value. |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Examples:
{% highlight ruby %}
wait_check_tolerance_raw("INST HEALTH_STATUS COLLECTS", 10.0, 5.0, 10)
{% endhighlight %}

### wait_check_expression

The wait_check_expression method pauses the script until an expression is evaluated to be true or a timeout occurs. If a timeout occurs the script will stop. This method can be used to perform more complicated comparisons than using wait as shown in the example. Also see the syntax notes for [check_expression](#checkexpression).

Syntax:
{% highlight ruby %}
wait_check_expression("<Expression>", <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Expression | A ruby expression to evaluate. |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting for the comparison to be true. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_check_expression("tlm('INST HEALTH_STATUS COLLECTS') > 5 and tlm('INST HEALTH_STATUS TEMP1') > 25.0", 10)
{% endhighlight %}

### wait_check_packet

The wait_check_packet method pauses the script until a certain number of packets have been received. If a timeout occurs the script will stop.

Syntax:
{% highlight ruby %}
wait_check_packet("<Target>", "<Packet>", <Num Packets>, <Timeout>, <Polling Rate (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target | The target name |
| Packet | The packet name |
| Num Packets | The number of packets to receive |
| Timeout | Timeout in seconds. Script will stop if the wait statement times out waiting specified number of packets. |
| Polling Rate | How often the comparison is evaluated in seconds. Defaults to 0.25 if not specified. |

Example:
{% highlight ruby %}
wait_check_packet('INST', 'HEALTH_STATUS', 5, 10) # Wait for 5 INST HEALTH_STATUS packets over 10s
{% endhighlight %}

## Limits

These methods deal with handling telemetry limits.

### limits_enabled?
The limits_enabled? method returns true/false depending on whether limits are enabled for a telemetry item.

Syntax:
``` limits_enabled?("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name| Name of the telemetry item. |

Example:
{% highlight ruby %}
enabled = limits_enabled?("INST HEALTH_STATUS TEMP1")
{% endhighlight %}

### enable_limits

The enable_limits method enables limits monitoring for the specified telemetry item.

Syntax:
``` enable_limits("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
enable_limits("INST HEALTH_STATUS TEMP1")
{% endhighlight %}

### disable_limits
The disable_limits method disables limits monitoring for the specified telemetry item.

Syntax:
``` disable_limits("<Target Name> <Packet Name> <Item Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |

Example:
{% highlight ruby %}
disable_limits("INST HEALTH_STATUS TEMP1")
{% endhighlight %}

### enable_limits_group

The enable_limits_group method enables limits monitoring on a set of telemetry items specified in a limits group.

Syntax:
``` enable_limits_group("<Limits Group Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Limits Group Name | Name of the limits group. |

Example:
{% highlight ruby %}
enable_limits_group("SAFE_MODE")
{% endhighlight %}

### disable_limits_group

The disable_limits_group method disables limits monitoring on a set of telemetry items specified in a limits group.

Syntax:
``` disable_limits_group("<Limits Group Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Limits Group Name | Name of the limits group. |

Example:
{% highlight ruby %}
disable_limits_group("SAFE_MODE")
{% endhighlight %}

### get_limits_groups

The get_limits_groups method returns the list of limits groups in the system.

Syntax:
``` get_limits_groups() ```

Example:
{% highlight ruby %}
limits_groups = get_limits_groups()
{% endhighlight %}

### set_limits_set

The set_limits_set method sets the current limits set. The default limits set is :DEFAULT.

Syntax:
``` set_limits_set("<Limits Set Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Limits Set Name | Name of the limits set. |

Example:
{% highlight ruby %}
set_limits_set("DEFAULT")
{% endhighlight %}

### get_limits_set

The get_limits_set method returns the name of the current limits set. The default limits set is :DEFAULT.

Syntax:
``` get_limits_set() ```

Example:
{% highlight ruby %}
limits_set = get_limits_set()
{% endhighlight %}

### get_limits_sets

The get_limits_sets method returns the list of limits sets in the system.

Syntax:
``` get_limits_sets() ```

Example:
{% highlight ruby %}
limits_sets = get_limits_sets()
{% endhighlight %}

### get_limits

The get_limits method returns limits settings for a telemetry point.

Syntax:
{% highlight ruby %}
get_limits(<Target Name>, <Packet Name>, <Item Name>, <Limits Set (optional)>)
{% endhighlight %}e

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Limits Set | Get the limits for a specific limits set. If not given then it defaults to returning the settings for the current limits set. |

Example:
{% highlight ruby %}
limits_set, persistence_setting, enabled, red_low, yellow_low, yellow_high, red_high, green_low, green_high = get_limits('INST', 'HEALTH_STATUS', 'TEMP1')
{% endhighlight %}

### set_limits
The set_limits_method sets limits settings for a telemetry point.  Note: In most cases it would be better to update your config files or use different limits sets rather than changing limits settings in realtime.

Syntax:
{% highlight ruby %}
set_limits(<Target Name>, <Packet Name>, <Item Name>, <Red Low>, <Yellow Low>, <Yellow High>, <Red High>, <Green Low (optional)>, <Green High (optional)>, <Limits Set (optional)>, <Persistence (optional)>, <Enabled (optional)>)
{% endhighlight %}

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target of the telemetry item. |
| Packet Name | Name of the telemetry packet of the telemetry item. |
| Item Name | Name of the telemetry item. |
| Red Low | Red Low setting for this limits set. Any value below this value will be make the item red. |
| Yellow Low | Yellow Low setting for this limits set. Any value below this value but greater than Red Low will be make the item yellow. |
| Yellow High | Yellow High setting for this limits set. Any value above this value but less than Red High will be make the item yellow. |
| Red High | Red High setting for this limits set. Any value above this value will be make the item red. |
| Green Low | Optional. If given, any value greater than Green Low and less than Green_High will make the item blue indicating a good operational value. |
| Green High | Optional. If given, any value greater than Green Low and less than Green_High will make the item blue indicating a good operational value. |
| Limits Set | Optional. Set the limits for a specific limits set. If not given then it defaults to setting limts for the :CUSTOM limits set. |
| Persistence | Optional. Set the number of samples this item must be out of limits before changing limits state. Defaults to no change. Note: This affects all limits settings across limits sets. |
| Enabled | Optional. Whether or not limits are enabled for this item. Defaults to true. Note: This affects all limits settings across limits sets. |

Example:
{% highlight ruby %}
set_limits('INST', 'HEALTH_STATUS', 'TEMP1', -10.0, 0.0, 50.0, 60.0, 30.0, 40.0, :TVAC, 1, true)
{% endhighlight %}

### get_out_of_limits

The get_out_of_limits method returns an array with the target_name, packet_name, item_name, and limits_state of all items that are out of their limits ranges.

Syntax:
``` get_out_of_limits() ```

Example:
{% highlight ruby %}
out_of_limits_items = get_out_of_limits()
{% endhighlight %}

### get_overall_limits_state

The get_overall_limits_state method returns the overall limits state for the COSMOS system.   Returns :GREEN, :YELLOW, :RED, or :STALE.

Syntax:
``` get_overall_limits_state(<ignored_items> (optional)) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Ignored Items | Array of arrays with items to ignore when determining the overall limits state. [['TARGET_NAME', 'PACKE_NAME', 'ITEM_NAME'], ...] |

Example:
{% highlight ruby %}
overall_limits_state = get_overall_limits_state()
overall_limits_state = get_overall_limits_state([['INST', 'HEALTH_STATUS', 'TEMP1']])
{% endhighlight %}

## Limits Events

Methods for handling limits events.

### subscribe_limits_events

The subscribe_limits_events method allows the user to listen for events regarding telemetry items going out of limits or changes in limits set. A unique id is returned to the tool which is used to retrieve the events.

Syntax:
``` subscribe_limits_events(<Queue Size (optional)>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Queue Size | How many limits events to queue up before dropping the client. Defaults to 1000 if not given. |

Example:
{% highlight ruby %}
id = subscribe_limits_events()
{% endhighlight %}

### unsubscribe_limits_events

The unsubscribe_limits_events method allows the user to stop listening for events regarding telemetry items going out of limits or changes in limits set.

Syntax:
``` unsubscribe_limits_events(<id>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| id | Unique id given to the user by subscribe_limits_events. |

Example:
{% highlight ruby %}
unsubscribe_limits_events(id)
{% endhighlight %}

### get_limits_event

The get_limits_event method returns a limits event to the user who has already subscribed to limits event. Can be run in a non-blocking or blocking manner.

Syntax:
``` get_limits_event(<id>, <non_block (optional)>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| id | Unique id given to the tool by subscribe_limits_events. |
| non_block | Boolean to indicate if the method should block until an event is received or not. Defaults to false. |

Example:
{% highlight ruby %}
event = get_limits_event(id, true)
puts event.inspect # [:LIMITS_CHANGE, "TARGET_NAME", "PACKET_NAME", "ITEM_NAME", :OLD_STATE, :NEW_STATE)
puts event.inspect # [:LIMITS_SET, :NEW_LIMITS_SET)
puts event.inspect # [:LIMITS_SETTINGS, "TARGET_NAME", "PACKET_NAME", "ITEM_NAME", :LIMITS_SET, persistence_setting, enabled_flag, red_low, yellow_low, yellow_high, red_high, green_low, green_high)
{% endhighlight %}

## Targets

Methods for getting knowledge about targets.

### get_target_list

The get_target_list method returns a list of the targets in the system in an array.

Syntax:
``` get_target_list() ```

Example:
{% highlight ruby %}
targets = get_target_list()
{% endhighlight %}

## Interfaces

These methods allow the user to manipulate COSMOS interfaces.

### connect_interface

The connect_interface method connects to targets associated with a COSMOS interface.

Syntax:
```connect_interface("<Interface Name>", <Interface Parameters (optional)>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the interface. |
| Interface Parameters | Parameters used to initialize the interface. If none are given then the interface will use the parameters that were given in the server configuration file. |

Example:
{% highlight ruby %}
connect_interface("INT1")
{% endhighlight %}

### disconnect_interface

The disconnect_interface method disconnects from targets associated with a COSMOS interface.

Syntax:
``` disconnect_interface("<Interface Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name| Name of the interface. |

Example:
{% highlight ruby %}
disconnect_interface("INT1")
{% endhighlight %}

### interface_state

The interface_state method retrieves the current state of a COSMOS interface. Returns either 'CONNECTED', 'DISCONNECTED', or 'ATTEMPTING'.

Syntax:
``` interface_state("<Interface Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the interface. |

Example:
{% highlight ruby %}
interface_state("INT1")
{% endhighlight %}

### map_target_to_interface

The map_target_to_interface method allows a target to be mapped to an interface in realtime. If the target is already mapped to an interface it will be unmapped from the existing interface before being mapped to the new interface.

Syntax:
``` map_target_to_interface("<Target Name>", "<Interface Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Target Name | Name of the target. |
| Interface Name | Name of the interface. |

Example:
{% highlight ruby %}
map_target_to_interface("INST", "INT2")
{% endhighlight %}

### get_interface_names

The get_interface_names method returns a list of the interfaces in the system in an array.

Syntax:
``` get_interface_names() ```

Example:
{% highlight ruby %}
interface_names = get_interface_names()
{% endhighlight %}

## Routers

These methods allow the user to manipulate COSMOS routers.

### connect_router

The connect_router method connects a COSMOS router.

Syntax:
``` connect_router("<Router Name>", <Router Parameters (optional)>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Router Name | Name of the router. |
| Router Parameters | Parameters used to initialize the router. If none are given then the routerwill use the parameters that were given in the server configuration file. |

Example:
{% highlight ruby %}
connect_ROUTER("INT1_ROUTER")
{% endhighlight %}

### disconnect_router

The disconnect_router method disconnects a COSMOS router.

Syntax:
``` disconnect_router("<Router Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Router Name | Name of the router. |

Example:
{% highlight ruby %}
disconnect_router("INT1_ROUTER")
{% endhighlight %}

### router_state

The router_state method retrieves the current state of a COSMOS router. Returns either 'CONNECTED', 'DISCONNECTED', or 'ATTEMPTING'.

Syntax:
``` router_state("<Router Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Router Name | Name of the router. |

Example:
{% highlight ruby %}
router_state("INT1_ROUTER")
{% endhighlight %}

### get_router_names

The get_router_names method returns a list of the routers in the system in an array.

Syntax:
``` get_router_names() ```

Example:
{% highlight ruby %}
router_names = get_router_names()
{% endhighlight %}

## Logging

These methods control command and telemetry logging.

### get_cmd_log_filename

The get_cmd_log_filename method retrieves the current command log file for the specified log writer. Returns nil if not logging.

Syntax:
``` get_cmd_log_filename("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer. Defaults to "DEFAULT" |

Example:
{% highlight ruby %}
get_cmd_log_filename("INT1")
{% endhighlight %}

### get_tlm_log_filename

The get_tlm_log_filename method retrieves the current telemetry log file for the specified log writer. Returns nil if not logging.

Syntax:
``` get_tlm_log_filename("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the interface. |

Example:
{% highlight ruby %}
get_tlm_log_filename("INT1")
{% endhighlight %}

### start_logging

The start_logging method starts logging of commands sent and telemetry received for a packet log writer.  If a log writer is already logging, this will start a new log file.

Syntax:
``` start_logging("<Packet Log Writer Name (optional)>", "<Label (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to start logging. Defaults to 'ALL' which causes all packet log writers to start logging commands and telemetry. If a log writer is already logging it will start a new file. |
| Label | Label to place on log files. Defaults to nil which means no label. Labels must consist of only letters and numbers (no underscores, hyphens, etc). |

Example:
{% highlight ruby %}
start_logging("int1")
{% endhighlight %}

### start_cmd_log

The start_cmd_log method starts logging of commands sent.   If a log writer is already logging, this will start a new log file.

Syntax:
``` start_cmd_log("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to start logging. Defaults to 'ALL' which causes all packet log writers to start logging commands. If a log writer is already logging it will start a new file. |
| Label | Label to place on log files. Defaults to nil which means no label. |

Example:
{% highlight ruby %}
start_cmd_log("int1")
{% endhighlight %}

### start_tlm_log

The start_tlm_log method starts logging of telemetry received.   If a log writer is already logging, this will start a new log file.

Syntax:
``` start_tlm_log("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to start logging. Defaults to 'ALL' which causes all packet log writers to start logging telemetry. If a log writer is already logging it will start a new file. |
| Label | Label to place on log files. Defaults to nil which means no label. |

Example:
{% highlight ruby %}
start_tlm_log("int1")
{% endhighlight %}

### stop_logging

The stop_logging method stops logging of commands sent and telemetry received for a packet log writer.

Syntax:
``` stop_logging("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to stop logging. Defaults to 'ALL' which causes all packet log writers to stop logging commands and telemetry. |

Example:
{% highlight ruby %}
stop_logging("int1")
{% endhighlight %}

### stop_cmd_log

The stop_cmd_log method stops logging of commands sent.

Syntax:
``` stop_cmd_log("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to stop logging. Defaults to 'ALL' which causes all packet log writers to stop logging commands. |

Example:
{% highlight ruby %}
stop_cmd_log()
{% endhighlight %}

### stop_tlm_log

The stop_tlm_log method stops logging of telemetry received.

Syntax:
``` stop_tlm_log("<Packet Log Writer Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Packet Log Writer Name | Name of the packet log writer to command to stop logging. Defaults to 'ALL' which causes all packet log writers to stop logging telemetry. |

Example:
{% highlight ruby %}
stop_tlm_log()
{% endhighlight %}

### get_server_message_log_filename

Returns the filename of the COSMOS Command and Telemetry Server message log.

Syntax:
``` get_server_message_log_filename() ```

Example:
{% highlight ruby %}
filename = get_server_message_log_filename()
{% endhighlight %}

### start_new_server_message_log

Starts a new COSMOS Command and Telemetry Server message log.

Syntax:
``` start_new_server_message_log() ```

Example:
{% highlight ruby %}
start_new_server_message_log()
{% endhighlight %}

### start_raw_logging_interface

The start_raw_logging_interface method starts logging of raw data on one or all interfaces.   This is for debugging purposes only.

Syntax:
``` start_raw_logging_interface("<Interface Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the Interface to command to start raw data logging. Defaults to 'ALL' which causes all interfaces that support raw data logging to start logging raw data. |

Example:
{% highlight ruby %}
start_raw_logging_interface ("int1")
{% endhighlight %}

### stop_raw_logging_interface

The stop_raw_logging_interface method stops logging of raw data on one or all interfaces.   This is for debugging purposes only.

Syntax:
``` stop_raw_logging_interface("<Interface Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Interface Name | Name of the Interface to command to stop raw data logging. Defaults to 'ALL' which causes all interfaces that support raw data logging to stop logging raw data. |

Example:
{% highlight ruby %}
stop_raw_logging_interface ("int1")
{% endhighlight %}

### start_raw_logging_router

The start_raw_logging_router method starts logging of raw data on one or all routers.   This is for debugging purposes only.

Syntax:
``` start_raw_logging_router("<Router Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Router Name | Name of the Router to command to start raw data logging. Defaults to 'ALL' which causes all routers that support raw data logging to start logging raw data. |

Example:
{% highlight ruby %}
start_raw_logging_router("router1")
{% endhighlight %}

### stop_raw_logging_router

The stop_raw_logging_router method stops logging of raw data on one or all routers.   This is for debugging purposes only.

Syntax:
``` stop_raw_logging_router("<Router Name (optional)>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Router Name | Name of the Router to command to stop raw data logging.  Defaults to 'ALL' which causes all routers that support raw data logging to stop logging raw data. |

Example:
{% highlight ruby %}
stop_raw_logging_router("router1")
{% endhighlight %}

## Executing Other Procedures

These methods allow the user to bring in files of subroutines and execute other test procedures.

### start

The start method starts execution of another high level test procedure. No parameters can be given to high level test procedures. If parameters are necessary, then consider using a subroutine.

Syntax:
``` start("<Procedure Filename>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Procedure Filename | Name of the test procedure file. These files are normally in the procedures folder but may be anywhere in the Ruby search path. Additionally, absolute paths are supported. |

Example:
{% highlight ruby %}
start("test1.rb")
{% endhighlight %}

### load_utility

The load_utility method reads in a script file that contains useful subroutines for use in your test procedure.   When these subroutines run in ScriptRunner or TestRunner, their lines will not be highlighted.  This is very useful for methods containing loops which can be slow to execute when highlighting lines.

Syntax:
``` load_utility("<Utility Filename>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Utility Filename | Name of the script file containing subroutines. These files are normally in the procedures folder but may be anywhere in the Ruby search path. Additionally, absolute paths are supported. |

Example:
{% highlight ruby %}
load_utility("mode_changes.rb")
{% endhighlight %}

## Opening and Closing Telemetry Screens

These methods allow the user to open or close telemetry screens from within a test procedure.

### display

The display method opens a telemetry screen at the specified position.

Syntax:
``` display("<Display Name>", <X Position (optional)>, <Y Position (optional)>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Display Name | Name of the telemetry screen to display. Screens are normally named by "TARGET_NAME SCREEN_NAME" |
| X Position | The X coordinate on screen where the top left corner of the telemetry screen will be placed. |
| Y Position | The Y coordinate on screen where the top left corner of the telemetry screen will be placed. |

Example:
{% highlight ruby %}
display("INST ADCS", 100, 200)
{% endhighlight %}

### clear

The clear method closes an open telemetry screen.

Syntax:
``` clear("<Display Name>") ```

| Parameter | Description |
| -------- | --------------------------------- |
| Display Name | Name of the telemetry screen to close. Screens are normally named by "TARGET_NAME SCREEN_NAME" |

Example:
{% highlight ruby %}
clear("INST ADCS")
{% endhighlight %}

## Script Runner Specific Functionality

These methods allow the user to interact with ScriptRunner functions.

### set_line_delay

This method sets the line delay in script runner.

Syntax:
``` set_line_delay(<delay>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| delay | The amount of time script runner will wait between lines when executing a script, in seconds. Should be ≥ 0.0 |

Example:
{% highlight ruby %}
set_line_delay(0.0)
{% endhighlight %}

### get_line_delay

The method gets the line delay that script runner is currently using.

Syntax:
``` get_line_delay() ```

Example:
{% highlight ruby %}
curr_line_delay = get_line_delay()
{% endhighlight %}

### get_scriptrunner_message_log_filename

Returns the filename of the ScriptRunner message log.

Syntax:
``` get_scriptrunner_message_log_filename() ```

Example:
{% highlight ruby %}
filename = get_scriptrunner_message_log_filename()
{% endhighlight %}

### start_new_scriptrunner_message_log

Starts a new ScriptRunner message log.   Note:  ScriptRunner will automatically start a new log whenever a script is started.  This method is only needed for starting a new log mid-script execution.

Syntax:
``` start_new_scriptrunner_message_log() ```

Example:
{% highlight ruby %}
filename = start_new_scriptrunner_message_log()
{% endhighlight %}

### disable_instrumentation
*** Added in COSMOS 3.3.3 ***

Disables instrumentation for a block of code (line highlighting and exception catching).  This is especially useful for speeding up loops that are very slow if lines are instrumented.
Consider breaking code like this into a seperate file and using either require/load to read the file for the same effect while still allowing errors to be caught by your script.

*** WARNING:  Use with caution. Disabling instrumentation will cause any error that occurs while disabled to cause your script to completely stop. ***

Syntax:
``` disable_instrumentation do ```

Example:
{% highlight ruby %}
disable_instrumentation do
  1000.times do
    # Don't want this to have to highlight 1000 times
  end
end
{% endhighlight %}

### set_stdout_max_lines
*** Added in COSMOS 3.3.3 ***

This method sets the maximum amount of lines of output that a single line in Scriptrunner can generate without being truncated.

Syntax:
``` set_stdout_max_lines(max_lines) ```

| Parameter | Description |
| -------- | --------------------------------- |
| max_lines | The maximum number of lines that will be written to the ScriptRunner log at once |

Example:
{% highlight ruby %}
set_stdout_max_lines(2000)
{% endhighlight %}

## Debugging

These methods allow the user to debug scripts with ScriptRunner.

### insert_return

Inserts a ruby return statement into the currently executing context. This can be used to break out of methods early from the ScriptRunner Debug prompt.

Syntax:
``` insert_return (<return value (optional)>, …) ```

| Parameter | Description |
| -------- | --------------------------------- |
| return value | One or more values that are returned from the method |

Example(s):
{% highlight ruby %}
insert_return()
insert_return(5, 10)
{% endhighlight %}

### step_mode

Places ScriptRunner into step mode where Go must be hit to proceed to the next line.

Syntax:
``` step_mode() ```

Example:
{% highlight ruby %}
step_mode()
{% endhighlight %}

### run_mode

Places ScriptRunner into run mode where the next line is run automatically.

Syntax:
``` run_mode() ```

Example:
{% highlight ruby %}
run_mode()
{% endhighlight %}

### show_backtrace

Makes ScriptRunner print out a backtrace when an error occurs.   Also prints out a backtrace for the most recent error.

Syntax:
``` show_backtrace(<true or false>) ```

Example:
{% highlight ruby %}
show_backtrace(true)
{% endhighlight %}

### shutdown_cmd_tlm

The shutdown_cmd_tlm method disconnects from the Command and Telemetry Server. This is good practice to do before your tool shuts down.

Syntax:
``` shutdown_cmd_tlm() ```

Example:
{% highlight ruby %}
shutdown_cmd_tlm()
{% endhighlight %}

### set_cmd_tlm_disconnect

The set_cmd_tlm_disconnect method puts scripting into or out of disconnect mode.  In disconnect mode, messages are not sent to CmdTlmServer.  Instead things are reported as nominally succeeding.   Disconnect mode is useful for dry-running scripts without having a connected CmdTlmServer.

Syntax:
``` set_cmd_tlm_disconnect(<Disconnect>, <Config File>) ```

| Parameter | Description |
| -------- | --------------------------------- |
| Disconnect | True or Fase. True enters disconnect mode and False leaves it. |
| Config File | Command and Telemetry Server configuration file to use to simulate the CmdTlmServer. Defaults to cmd_tlm_server.txt. |

Example:
{% highlight ruby %}
set_cmd_tlm_disconnect(true)
{% endhighlight %}

### get_cmd_tlm_disconnect

The get_cmd_tlm_disconnect method returns true if currently in disconnect mode.

Syntax:
``` get_cmd_tlm_disconnect() ```

Example:
{% highlight ruby %}
mode = get_cmd_tlm_disconnect()
{% endhighlight %}
