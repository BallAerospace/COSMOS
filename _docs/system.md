---
layout: docs
title: System Configuration
permalink: /docs/system/
toc: true
---
This document provides the information necessary to configure the COSMOS Command and Telemetry Server and other top level configuration options for your unique project.

Configuration file formats for the following are provided:

 * system.txt (found in config/system)
 * target.txt (found in config/targets/TARGETNAME)
 * cmd_tlm_server.txt (found in config/targets/TARGETNAME and config/tools/cmd_tlm_server)
 * crc.txt (found in data/crc.txt)

## System Configuration
The COSMOS system configuration is performed by system.txt in the config/system directory. This file declares all the targets that will be used by COSMOS as well as top level configuration information which is primarily used by the Command and Telemetry Server.

By default, all COSMOS tools use the config/system/system.txt file. However, all tools can take a custom system configuration file by passing the "–system <filename>" option to the tool when it starts. NOTE: Mixing system configuration files between tools can be confusing as some tools could be configured with more or less targets than the Command and Telemetry Server. However, this is the only way to control which targets, ports, paths, and log writers are used by the various tools.

## system.txt Keywords

### AUTO_DECLARE_TARGETS
If this keyword is present, COSMOS will automatically load all the target folders under config/targets into the system. The target folders must be uppercase and be named according to how COSMOS will access them. For example, if you create a config/targets/INST directory, COSMOS will create a target named 'INST' which is how it will be referenced in command and telemetry. This keyword is REQUIRED unless you individually declare your targets using the DECLARE_TARGET keyword.

Example Usage:
{% highlight bash %}
AUTO_DECLARE_TARGETS
{% endhighlight %}

### DECLARE_TARGET
Declare target is used in place of AUTO_DECLARE_TARGETS to give more fine grained control over how the target folder is loaded and named within COSMOS. This is required if AUTO_DECLARE_TARGET is not present.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Target Name | The directory name which contains the target information. This must match a directory under config/targets. | Yes |
| Substitute Target Name | The target name in the COSMOS system. This is how the target will be referred to in scripts. If this is not given (or given as nil) the target name will be the directory name given above. | No |
| Target Filename | The name of the file in the target directory which contains the configuration information for the target. By default this is 'target.txt' but if you want to rename this you need to set this parameter. | No |

Example Usage:
{% highlight bash %}
DECLARE_TARGET INST INST2 inst.txt
{% endhighlight %}

### PORT
Port is used to set the default ports used by the Command and Telemetry Server. It is not necessary to set this option unless you wish to override the defaults (given in the example usage).   Overriding ports is necessary if you want to run two Command and Telemetry Servers on the same computer simultaneously.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Port Name | Port name to set. Must be one of the following: 'CTS_API', 'TLMVIEWER_API', 'CTS_PREIDENTIFIED'. CTS_API - This port is what tools connect to to communicate with the COSMOS Scripting API. TLMVIEWER_API - This port is used to remotely open and close telemetry screens in Telemetry Viewer. CTS_PREIDENTIFIED - This port provides access to a preidentified stream of all telemetry packets in the system. This is currently used by Telemetry Grapher and can be used to chain Command and Telemetry Servers together. | Yes |
| Port Value | Port number to use for the specified port name. | Yes |

Example Usage:
{% highlight bash %}
PORT CTS_API 7777 # Default
PORT TLMVIEWER_API 7778 # Default
PORT CTS_PREIDENTIFIED 7779 # Default
{% endhighlight %}

### PATH
Path is used to set the default paths used by the Command and Telemetry Server to access or create files. It is not necessary to set this option unless you wish to override the defaults (given in the example usage).

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Path Name | Path name to set. Must be one of the following: 'LOGS', 'TMP', 'SAVED_CONFIG', 'TABLES', 'PROCEDURES', 'HANDBOOKS'. | Yes |
| Path Value | File system path to use for the specified path name. | Yes |

Example Usage:
{% highlight bash %}
PATH LOGS './logs' # Default location of system and tool log files
PATH TMP './tmp' # Default location of temporary marshal files
PATH SAVED_CONFIG './saved_config' # Default location of saved configurations (see note)
PATH TABLES './tables' # Default location of table files
PATH PROCEDURES './procedures' # Default location of Script procedure files
PATH HANDBOOKS './handbooks' # Default location to place handbook files
{% endhighlight %}

The PROCEDURES path must be set for Script Runner and Test Runner to locate your procedure files. You can add multiple 'PATH PROCEDURES' lines to your configuration file to set multiple locations.

The SAVED_CONFIG option sets the location of saved configuration. A saved configuration is a snapshot in time of when COSMOS parses all the target directories called out by either AUTO_DECLARE_TARGETS or DECLARE_TARGET. If something has changed in a target configuration, COSMOS will create a new directory in the saved_config folder containing this new target configuration. These directories should NOT be deleted as they provide a way for COSMOS to go back in time to a known configuration when parsing old binary log files. Only if you're sure you do not want this configuration history, e.g. you are developing your configuration and it is constantly changing, you can delete these folders.

### DEFAULT_PACKET_LOG_WRITER and DEFAULT_PACKET_LOG_READER
Default packet log writer and reader are used to set the class COSMOS uses when creating and reading binary packet log files. It is not necessary to set these options unless you wish to override the defaults (given in the example usage). NOTE: You should NOT override the default without consulting a COSMOS expert as this may break the ability to successfully read and write log files throughout the COSMOS system.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Filename | Ruby file to use when instantiating a new log writer / reader | Yes |

Example Usage:
{% highlight bash %}
DEFAULT_PACKET_LOG_WRITER packet_log_writer.rb # Default
DEFAULT_PACKET_LOG_READER packet_log_reader.rb # Default
{% endhighlight %}

### CMD_TLM_VERSION
Cmd tlm version is used to set an arbitrary command and telemetry version string which can be accessed in telemetry. This is useful in scripts for reporting a program specific version that changes along with another configuration management system.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Version | Arbitrary string | Yes |

Example Usage:
{% highlight bash %}
CMD_TLM_VERSION 1.0
CMD_TLM_VERSION A
CMD_TLM_VERSION 'Version A'
{% endhighlight %}

Note that quotes are only necessary to preserve spaces in your version string.

### STALENESS_SECONDS
Staleness seconds represent the number of seconds that must expire without seeing a packet before COSMOS marks it as 'stale'. This is identified in telemetry screens by all the telemetry items in the stale packet being colored purple. It is not necessary to set this option unless you wish to override the default (given in the example usage).

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Seconds | Integer number of seconds before packets are marked stale | Yes |

Example Usage:
{% highlight bash %}
STALENESS_SECONDS 30 # Default
{% endhighlight %}

### ENABLE_DNS (COSMOS 3.5.0+)
Enable DNS allows you to enable reverse DNS lookups for when tools connect to the Command and Telemetry Server's pre-identified socket or to any target using the TCPIP Server Interface. As of COSMOS 3.5.0 the default is to not use DNS.

{% highlight bash %}
Example Usage: ENABLE_DNS
{% endhighlight %}

### DISABLE_DNS
Disable DNS allows you to disable reverse DNS lookups for when tools connect to the Command and Telemetry Server's pre-identified socket or to any target using the TCPIP Server Interface. This is useful when you are in an environment where DNS is not available. As of COSMOS 3.5.0 the default is to not use DNS.

{% highlight bash %}
Example Usage: DISABLE_DNS
{% endhighlight %}

### ENABLE_SOUND (COSMOS 3.5.0+)
Enable sound makes any prompts that occur in ScriptRunner/TestRunner make an audible sound when they popup to alert the operator of needed input.

{% highlight bash %}
Example Usage: ENABLE_SOUND
{% endhighlight %}

### ALLOW_ACCESS
Allow access provides the ability to individually permit machines to connect to the COSMOS Command and Telemetry Server. It is not necessary to set this option unless you wish to override the default (given in the example usage).

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Machine Name or IP Address | Machine name to allow access | Yes |

Example Usage:
{% highlight bash %}
ALLOW_ACCESS ALL # Default
{% endhighlight %}

## Target Configuration
Each target is self contained in a target directory named after the target and placed in the config/targets directory. In the target directory there is a configuration file named target.txt which configures the individual target.

## target.txt Keywords

### REQUIRE

Require is used to load additional Ruby files located in the target's lib directory. These files are typically used to implement additional functionality like custom interfaces, limits responses, complex conversions, etc.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Filename | The name of the file to require. The file must be in the target's lib directory to be located.|Yes


Example Usage:
{% highlight bash %}
REQUIRE limits_response.rb
{% endhighlight %}

### IGNORE_PARAMETER

Ignore Parameter is used to ignore those command parameters which are required by the command protocol but do not change and can be safely ignored by the user. A good example are the CCSDS header parameters which are required by the protocol but are fixed and therefore should not be displayed to the user (by default) as they do not require user input.
The tools using the list of ignored parameters are:
Command Sender - It will not display (by default) parameters in this list. It will display the list via a GUI option.
Command and Telemetry Server - It will not display the ignored parameters in the command log
Script Runner (and various others) - It will not display the ignored parameters when doing code completion on a command

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Parameter Name | The name of the parameter to ignore in various tools. For example, command sender will not display ignored parameters by default. | Yes |

Example Usage:
{% highlight bash %}
IGNORE_PARAMETER CCSDS_VERSION
{% endhighlight %}

### IGNORE_ITEM
Ignore Item is used by various tools to ignore telemetry items which must be present but don't change much or aren't directly useful to the user. A good example are the CCSDS header parameters which are required by the protocol but are fixed.
The tools using the list of ignore items are:
Command and Telemetry Server - The API routine all_item_strings does not return ignored items
Script Runner - Script Audits ignore items when determining which telemetry items were checked

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Item Name | The name of the item to ignore in various tools. For example, Telemetry Viewer will not include these items in the screen audit. | Yes |

Example Usage:
{% highlight bash %}
IGNORE_ITEM CCSDS_VERSION
{% endhighlight %}

### COMMANDS and TELEMETRY
The commands and telemetry keywords are used to override the default COSMOS behavior of loading all the files located in the target's cmd_tlm directory. If any commands or telemetry keywords are used, COSMOS will no longer load all files in the target's cmd_tlm folder by default but will instead load only the files indicated by these keywords. This can be useful if you have different configurations of a target within a single target folder.  It is also necessary if you don't want the files to be processed in alphabetical order.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Filename | The name of the file in the cmd_tlm directory to load. | Yes |

Example Usage:
{% highlight bash %}
COMMANDS inst_cmds_v2.txt
TELEMETRY inst_tlm_v2.txt
{% endhighlight %}

### AUTO_SCREEN_SUBSTITUTE
This keyword causes all screens in the target to force substitute the targets name for all target names specified in the targets screen definition files.  This is useful in that it allows your target to be renamed simply be changing the folder name and not having to change any internal files.   Can not be used if more than one target is mentioned in a screen definition file.

Example Usage:
{% highlight bash %}
AUTO_SCREEN_SUBSTITUTE
{% endhighlight %}

## Command and Telemetry Server Configuration
The Command and Telemetry Server's configuration file is found in config/tools/cmd_tlm_server. This file is used to configure the server by primarily mapping the interfaces to the targets they service.

## cmd_tlm_server.txt Keywords

### TITLE
Title is used to set the title of the Command and Telemetry Server's window.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Title | Text to put in the title of the Server window | Yes |

Example Usage:
{% highlight bash %}
TITLE "COSMOS Command and Telemetry Server"
{% endhighlight %}

### PACKET_LOG_WRITER
Packet log writer is used to declare a packet log writer class and give it a name which can be referenced by an interface. This is required if you want interfaces to have their own dedicated log writers or want to combine various interfaces into a single log file. By default, COSMOS logs all data on all interfaces into a single command log and a single telemetry log. This keyword can also be used if you want to declare a different log file class to create log files. NOTE: You should NOT override the default (excluding using the meta_packet_log_writer.rb) without consulting a COSMOS expert as this may break the ability to successfully read and write log files.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Log Writer Name | The name of the log writer as reference by other cmd_tlm_server keywords. This name also appears in the Logging tab on the Command and Telemetry Server. | Yes |
| Filename | Ruby file to use when instantiating a new log writer (packet_log_writer.rb unless you have a custom log writer) | Yes |
| Parameters | Optional parameters to pass to the log writer class when instantiating it. The following parameters are the ones used by the default packet_log_writer.rb class. | Class specific |
| Log Name | Identifier to put in the log file name. This will be prepended with a date / time stamp and appended by the log type (cmd or tlm). Thus if you specify 'cosmos' the telemetry log will result in a file name of 'YYYY_MM_DD_HH_MM_SS_cosmostlm.bin'. The default is nil which means to just use 'cmd' and 'tlm' alone in the file names. | No |
| Logging Enabled | Whether to start with logging enabled. The default is true. | No |
| Cycle Time | The amount of time in seconds before creating a new log file. The default is nil which means files will grow indefinitely. | No |
| Cycle Size | The size in bytes before creating a new log file. The default is 2GB. | No |
| Log Directory | The directory to store the log files. The default is to use the system log directory defined in system.txt by the PATH LOGS. | No |
| Asynchronous | Whether to spawn a new thread to write packets to the log or write the packet to the log in the interface thread. The default is true. | No |

Example Usage:
{% highlight bash %}
PACKET_LOG_WRITER DEFAULT packet_log_writer.rb # Default
# The default logger filename will be <DATE>_cosmostlm.bin and will create a new log every 1MB
PACKET_LOG_WRITER DEFAULT packet_log_writer.rb cosmos true nil 1000000
# Create a logger named COSMOS_LOG which creates a new log every 5 min
PACKET_LOG_WRITER COSMOS_LOG packet_log_writer.rb cosmos true 600
{% endhighlight %}

### AUTO_INTERFACE_TARGETS
Auto interface targets is used to tell COSMOS to automatically look for a cmd_tlm_server.txt file at the top level of each target directory and use this file to configure the interface for that target. This is a good way of keeping the knowledge of how to interface to a target within that target. However, if you use substitute target names (by using DECLARE_TARGET) or use different IP addresses then this will not work and you'll have to use the INTERFACE_TARGET or INTERFACE keyword.


Example Usage:
{% highlight bash %}
AUTO_INTERFACE_TARGETS
{% endhighlight %}

### INTERFACE_TARGET
Interface target is used similarly to AUTO_INTERFACE_TARGETS except that it loads only the specified target's interface configuration file rather than all target configuration files.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Target Name | Name of the target | Yes |
| Configuration File | Configuration file name which contains the interface configuration. Defaults to 'cmd_tlm_server.txt'. | No |

Example Usage:
{% highlight bash %}
INTERFACE_TARGET COSMOS # Look in the COSMOS target directory for cmd_tlm_server.txt
INTERFACE_TARGET COSMOS config.txt # Look in the COSMOS target directory for config.txt
{% endhighlight %}

### INTERFACE
Interface is the keyword that should be present in a target directory's cmd_tlm_server.txt file if AUTO_INTERFACE_TARGETS or INTERFACE_TARGET is used. The interface keyword can also be used directly in the config/tools/cmd_tlm_server/cmd_tlm_server.txt file.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Interface Name | Name of the interface. This name will appear in the Interfaces tab of the Server and is also referenced by other keywords. | Yes |
| Filename | Ruby file to use when instantiating the interface. See the Interface Guide to learn more about the interfaces provided by COSMOS. | Yes |
| Parameters | Parameters to pass to the interface. See the Interface Guide to learn more about the interfaces provided by COSMOS. | Interface Specific |

Example Usage:
{% highlight bash %}
INTERFACE COSMOS_INT cmd_tlm_server_interface.rb
{% endhighlight %}

More examples provided in the Interface Guide.

### ROUTER
Router creates an interface which receives command packets from their remote targets and send them out their interfaces. They receive telemetry packets from their interfaces and send them to their remote targets. This allows routers to be intermediaries between an external client and an actual device.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Name | Name of the router | Yes |
| Filename | Ruby file to use when instantiating the interface. See the Interface Guide to learn more about the interfaces provided by COSMOS. | Yes |
| Parameters | Parameters to pass to the interface. See the Interface Guide to learn more about the interfaces provided by COSMOS. | Interface Specific |

### COLLECT_METADATA
COLLECT_METADATA keyword prompts the user for meta data when starting the CmdTlmServer.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Target Name | Target Name of the Metadata telemetry packet | Yes |
| Packet Name | Packet Name of the Metadata telemetry packet | Yes |

Example Usage:
{% highlight bash %}
COLLECT_METADATA META META
{% endhighlight %}

### BACKGROUND_TASK
Create a background task in the Server. The Server instantiates the class which must inherit from BackgroundTask and then calls the call() method which the class must implement. The call() method is only called once so if your background task is supposed to live on while the Server is running, you must implement your code in a loop with a sleep to not use all the CPU.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Filename | Ruby file which contains the background task implementation. Must inherit from BackgroundTask and implement the call method. | Yes |
| Optional Arguments | Optional arguments to the background task constructor | No |

Example Usage:
{% highlight bash %}
BACKGROUND_TASK example_background_task.rb
{% endhighlight %}

example_background_task.rb:
{% highlight ruby %}
require 'cosmos/tools/cmd_tlm_server/background_task'
module Cosmos
  class ExampleBackgroundTask < BackgroundTask
    def call
      while true
        # Call COSMOS API methods
        sleep 1 # 1Hz
      end
    end
  end
end
{% endhighlight %}

## Interface and Router Modifiers
The following keywords modify an interface and are only applicable after the INTERFACE or ROUTER keywords. They are indented to show ownership to the previously defined interface.

### TARGET
REQUIRED and only applicable to the INTERFACE keyword. Maps a target name to this interface which causes all the command and telemetry definitions to apply to the data being processed on the interface.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Target Name | Target name to map to this interface. Must match a known target name. | Yes |

### DONT_CONNECT
The Command and Telemetry Server will not try to connect to the given interface when starting up. Default is to connect on startup.

### DONT_RECONNECT
The Command and Telemetry Server will not try to reconnect to the given interface if the connection is lost. Default is auto reconnect.

### RECONNECT_DELAY
If DONT_RECONNECT is not present the Server will try to reconnect to an interface if the connection is lost. Reconnect delays sets the interval in seconds between reconnect tries.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Seconds | Delay in seconds between reconnect attempts. The default is 15 seconds. | Yes |

### DISABLE_DISCONNECT
Disable the Disconnect button on the Interfaces tab in the Server. This prevents the user from disconnecting from the interface.


### LOG
Enable logging on the interface by the specified log writer. This is only required if you want a log writer other than the default to log commands and telemetry on this interface.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Log Writer Name | Log writer name as defined by PACKET_LOG_WRITER | Yes |

### DONT_LOG
Disable logging commands and telemetry on this interface. Note this prevents logging from the Server on the Logging tab.

### LOG_RAW
Log all data on the interface exactly as it is sent and received. This does not add any COSMOS headers and thus can not be read by COSMOS tools. It is primarily useful for low level debugging of an interface.

### OPTION
Pass a specific option to the interface or router.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Option Name | Name of the option. | Yes |
| Option Value 1 | Value of the option. | Yes |
| Additional Option Values | 0 or more additional values given to the option | Option Specific |

### ROUTE
Only applies to routers. ROUTE declares which interfaces should use the current router. The given interface will then route all of its commands and telemetry through the router and out the interface defined by the router.

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| Interface Name | A previously defined interface name given by the INTERFACE keyword. | Yes |


Example Usage:
{% highlight bash %}
PACKET_LOG_WRITER COSMOS_LOG packet_log_writer.rb cosmos

INTERFACE COSMOS_INT cmd_tlm_server_interface.rb
  TARGET COSMOS
  DISABLE_DISCONNECT
  RECONNECT_DELAY 5
  LOG COSMOS_LOG
{% endhighlight %}

## Project CRC Checking
The COSMOS Launcher will check CRCs on project files if a data/crc.txt file is present. The file is made up of filename, a space character, and the expected CRC for the file. If the user updates the file from the Launcher legal dialog, the keyword USER_MODIFIED will be added to the top. This line should be deleted for an official release.

Example File:
{% highlight bash %}
lib/example_background_task.rb 0xCF0A70AF
lib/example_target.rb 0x5B7507D3
lib/user_version.rb 0x8F282EE9
{% endhighlight %}
