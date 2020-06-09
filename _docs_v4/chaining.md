---
layout: docs_v4
title: Chaining CmdTlmServers
---

There are two ways to chain CmdTlmServers to achieve two distinctly different results. One is to chain a client CmdTlmServer to a master to enable a separate workstation to have access to all the command and telemetry. The second is to connect a master CmdTlmServer to a client to allow a remote client to act as an interface to a target. Both methods will be discussed here.

## Chain Client CmdTlmServer to Master

Chaining a client CmdTlmServer to a master CmdTlmServer allows for running the COSMOS tools on other workstations and removing that processing load from a master CmdTlmServer that is directly connected to your targets. This is great for setting up workstations dedicated to graphing data, or viewing telemetry, without disturbing the main operation as the client will get all the same information as the master CmdTlmServer.

### Master CmdTlmServer Configuration

The default COSMOS Configuration already includes everything necessary to chain "child" CmdTlmServers. There is a default router called the PREIDENTIFIED_ROUTER that is listening on port 7779 by default. This is used to chain CmdTlmServers and is also used by TlmGrapher to access the full telemetry stream.

The only issue on the master CmdTlmServer computer is that you must make sure that the firewall is either disabled or that access to port 7779 is permitted.

### Child CmdTlmServer Configuration

1. Modify the example cmd_tlm_server_chain.txt file below
   - Change localhost to the IP address of your master CmdTlmServer
   - Update the TARGET keywords to include all of your targets
2. Put the updated cmd_tlm_server_chain.txt into config/tools/cmd_tlm_server/cmd_tlm_server_chain.txt
3. Start CmdTlmServer with (probably create a modified launcher.txt and associated .bat file):
   - `ruby CmdTlmServer --config cmd_tlm_server_chain.txt`

### Example CmdTlmServer Configuration for Child (cmd_tlm_server_chain.txt)

{% highlight bash %}

# Using this file WITH LOCALHOST requires changing the ports in system.txt

# Otherwise don't change the ports!

TITLE 'COSMOS Command and Telemetry Server - Chain Configuration'

# Don't log on the chained server

PACKET_LOG_WRITER DEFAULT packet_log_writer.rb nil false

# Replace localhost below with the IP Address of the master CmdTlmServer

# Update the target list below to the full list of targets in your system

# To make this child unable to send commands change the first 7779 to nil

INTERFACE CHAININT tcpip_client_interface.rb localhost 7779 7779 10 5 PREIDENTIFIED
TARGET INST
TARGET INST2
TARGET EXAMPLE
TARGET TEMPLATED
TARGET COSMOS
{% endhighlight %}

## Connect Master CmdTlmServer to Client

Connecting a master CmdTlmServer to a client CmdTlmServer is used when a client machine needs to interface directly to a target but the master CmdTlmServer also wants to view that target. For example, a machine is physically located next to a target which requires a serial interface (thus a serial cord connection) but the master CmdTlmServer is across the room. This technique connects the local machine to the target and then connects the master CmdTlmServer to the client. The client doesn't need to define the full configuration of the server and only has to configure the local target it is interfacing with. This technique can also be used to create multiple CmdTlmServers on the same machine. This is useful if you're experimenting with a target or background task and doing things that make the CmdTlmServer unstable.

### Child CmdTlmServer Configuration

The child COSMOS configuration should be configured as a totally stand alone COSMOS system. Follow the rest of the COSMOS documentation to set up the command and telemetry definitions and the interface definition in the target's cmd_tlm_server.txt file. When this is complete, you will have a config/targets/\<TARGET\> folder with your target's definition. Note that if you're creating a client CmdTlmServer on the same machine you'll need to adjust all the standard COSMOS ports in system.txt.

The client CmdTlmServer defines a default router called the PREIDENTIFIED_ROUTER that is listening on port 7779 by default. This will be used by the master CmdTlmServer to connect. Ensure that the firewall is either disabled or that access to port 7779 is permitted.

### Master CmdTlmServer Configuration

The master config/tools/cmd_tlm_server/cmd_tlm_server.txt file is where you define the interface to connect to the child CmdTlmServer.

1. Modify the example cmd_tlm_server.txt file below
   - Change localhost to the IP address of your client CmdTlmServer if the client is another machine
   - Change the port numbers if the client is running on the same machine
   - Update \<TARGET\> to match the target name from the client
2. Ensure your system.txt file has either AUTO_DECLARE_TARGETS or explictly declares the target via DECLARE_TARGET \<TARGET\>
3. Ensure your config/targets/\<TARGET\> folder matches the target definition on the client
   - Since the child and master CmdTlmServer share the same target definition, it is convenient to make this target an SVN external in one of the COSMOS configurations to ensure consistency between them

### Example CmdTlmServer Configuration for Master (cmd_tlm_server.txt)

{% highlight bash %}
TITLE 'COSMOS Command and Telemetry Server'

PACKET_LOG_WRITER DEFAULT packet_log_writer.rb

# Replace localhost below with the IP Address of the client CmdTlmServer

# Change <TARGET> to the target name as defined in the client

INTERFACE <TARGET>\_INT tcpip_client_interface.rb localhost 7779 7779 nil nil PREIDENTIFIED
TARGET <TARGET>
{% endhighlight %}
