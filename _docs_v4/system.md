---
layout: docs
title: System Configuration
toc: true
---

This document provides the information necessary to configure the COSMOS Command and Telemetry Server and other top level configuration options for your unique project.

Configuration file formats for the following are provided:

- system.txt (found in config/system)
- target.txt (found in config/targets/TARGETNAME)
- cmd_tlm_server.txt (found in config/targets/TARGETNAME and config/tools/cmd_tlm_server)
- crc.txt (found in data/crc.txt)

# System Configuration

The COSMOS system configuration is performed by system.txt in the config/system directory. This file declares all the targets that will be used by COSMOS as well as top level configuration information which is primarily used by the Command and Telemetry Server.

By default, all COSMOS tools use the config/system/system.txt file. However, all tools can take a custom system configuration file by passing the "–system <filename>" option to the tool when it starts. NOTE: Mixing system configuration files between tools can be confusing as some tools could be configured with more or less targets than the Command and Telemetry Server. However, this is the only way to control which targets, ports, paths, and log writers are used by the various tools.

{% cosmos_meta system.yaml %}

# Target Configuration

Each target is self contained in a target directory named after the target and placed in the config/targets directory. In the target directory there is a configuration file named target.txt which configures the individual target.

{% cosmos_meta target_config.yaml %}

# Command and Telemetry Server Configuration

The Command and Telemetry Server's configuration file is found in config/tools/cmd_tlm_server. This file is used to configure the server by primarily mapping the interfaces to the targets they service.

{% cosmos_meta cmd_tlm_server.yaml %}

# Project CRC Checking

The COSMOS Launcher will check CRCs on project files if a data/crc.txt file is present. The file is made up of filename, a space character, and the expected CRC for the file. If the user updates the file from the Launcher legal dialog, the keyword USER_MODIFIED will be added to the top. This line should be deleted for an official release.

Example File:
{% highlight bash %}
lib/example_background_task.rb 0xCF0A70AF
lib/example_target.rb 0x5B7507D3
lib/user_version.rb 0x8F282EE9
{% endhighlight %}
