---
layout: news_item
title: 'Using system.txt and target.txt'
date: 2018-10-05 08:00:00 -0700
author: jmthomas
categories: [post]
---
## system.txt
The COSMOS system configuration is performed by system.txt in the config/system directory. This file declares all the targets that will be used by COSMOS as well as top level configuration information which is primarily used by the Command and Telemetry Server.

By default, all COSMOS tools use the config/system/system.txt file. However, all tools can take a custom system configuration file by passing the "–system <filename>" option to the tool when it starts. This is typically done in the Launcher script as shown in the COSMOS demo. Here's an excerpt which shows how we're passing system2.txt using the --system option.

```
TOOL "Command and Telemetry Server" "LAUNCH CmdTlmServer --system system2.txt" "cts.png" --config cmd_tlm_server2.txt
```

### Using Multiple system.txt Files
So when would you want to create and use multiple system.txt files? Since system.txt defines the targets used by the system, you can use two different system.txt files to create two configurations which contain most but not all the same targets. For example, you have a test bench with 5 different test equipment targets but different test box targets: BOX1 and BOX2. You can create one COSMOS configuration for both test benches and create two different launcher files with different lists of targets.

## target.txt
The parsing of a COSMOS target is controlled by the target.txt file found at the root of the target directory. The COMMANDS and TELEMETRY keywords tell COSMOS which [Command](/docs/command) and [Telemetry](/docs/telemetry) files to parse. For example from the COSMOS demo INST [target.txt](https://github.com/BallAerospace/COSMOS/blob/master/demo/config/targets/INST/target.txt)

```
COMMANDS inst_cmds.txt
TELEMETRY inst_tlm.txt
```

Since we can tell COSMOS exactly which command and telemetry files to parse we can control how the target cmd/tlm definitions get built. This is useful if you have a target with slightly different command and telemetry definitions. This can happen for varous reasons like connecting to slightly different hardware revisions. The advantage of using a single target folder in this case (vs just copying and renaming the target folder) is that you can (potentially) reuse screens and target library code. Obviously this only works if the command and telemetry definitions are only slightly different between revisions.

### Combining system.txt and target.txt
When we combine the ability in system.txt to specify a specific target.txt file and the ability in target.txt to specify the command and telemetry definitions, we can create specific configurations for different environments.

This example is losely based on the COSMOS demo. First create two separate system.txt files called system1.txt and system2.txt:

Partial system1.txt:
```
DECLARE_TARGET INST nil target1.txt
```

Partial system2.txt
```
DECLARE_TARGET INST nil target2.txt
```

The target1.txt file in the INST target calls out one set of cmd/tlm files:
```
COMMANDS inst1_cmds.txt
TELEMETRY inst1_tlm.txt
```

The target2.txt file in the INST target calls out another set:
```
COMMANDS inst2_cmds.txt
TELEMETRY inst2_tlm.txt
```

You also have to ensure your Launcher scripts specify the correct system.txt file when launching the tools:

Partial launcher1.txt:
```
TOOL "Command and Telemetry Server" "LAUNCH CmdTlmServer --system system1.txt" "cts.png" --config cmd_tlm_server.txt
```

Partial launcher2.txt:
```
TOOL "Command and Telemetry Server" "LAUNCH CmdTlmServer --system system2.txt" "cts.png" --config cmd_tlm_server.txt
```

Once you have your launcher configurations in place you can create a simple Batch file or shell script to launch COSMOS.

Launcher1.bat:
```
call tools\Launcher.bat --config launcher1.txt
```

Launcher2.bat:
```
call tools\Launcher.bat --config launcher2.txt
```

With correct usage of system.txt and target.txt you can consolidate your COSMOS configurations and avoid copying and pasting. This makes your COSMOS configuration easier to test and maintain.

### Overriding Cmd/Tlm Definitions

Another way to modify a target is to override the target command and telemetry definitions. This is a useful practice if your target's command and telemetry files are generated from a database or from some other system and you want to add COSMOS specific features. It is also handy to add custom conversions and formatting for displays.

Create a file in the target's cmd_tlm folder named after the original file but with an extension like _override.txt. For example, you have the following telemetry definition file named inst_tlm.txt:

```
TELEMETRY INST HEALTH_STATUS BIG_ENDIAN "Health and status from the target"
  APPEND_ITEM COLLECTS         16 UINT     "Number of collects"
  APPEND_ITEM TEMP1            16 UINT     "Temperature #1"
```

Create another file called inst_tlm_override.txt and start overriding telemetry using the [SELECT_TELEMETRY](/docs/telemetry/#select_telemetry) and [SELECT_ITEM](/docs/telemetry/#select_item) keywords. Note that the filename is important because by default COSMOS processes cmd/tlm definition files in alphabetical order. For example, if you have a telemetry file named "telemetry.txt" and created a file called "override.txt", you would get an error because the telemetry file will not be processed before the override.

```
SELECT_TELEMETRY INST HEALTH_STATUS
  SELECT_ITEM COLLECTS
    FORMAT_STRING "0x%0X"
```

Note that you can include these override files as needed based on the target.txt file as described above.

If you have a question which would benefit the community you can ask on [StackOverflow](https://stackoverflow.com/questions/ask?tags=cosmos;ruby) or if you find a bug or want a feature please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
