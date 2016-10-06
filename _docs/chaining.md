---
layout: docs
title: Chaining CmdTlmServers
permalink: /docs/chaining/
---

Chaining CmdTlmServers allows for running the COSMOS tools on other workstations and removing that processing load from a main CmdTlmServer that is directly connected to your targets.  This is great for setting up workstations dedicated to graphing data, or viewing telemetry, without disturbing the main operation.

## Main CmdTlmServer Configuration

The default COSMOS Configuration already includes everything necessary to chain "child" CmdTlmServers.  There is a default router called the PREIDENTIFIED_ROUTER that is listening on port 7779 by default.  This is used to chain CmdTlmServers and is also used by TlmGrapher to access the full telemetry stream.

The only issue on the main CmdTlmServer computer is that you must make sure that the firewall is either disabled or that access to port 7779 is permitted.

## Child CmdTlmServer Configuration

1.	Modify the example cmd_tlm_server_chain.txt file below
    * Change localhost to the IP address of your main CmdTlmServer
    * Update the TARGET keywords to include all of your targets
2.	Put the updated cmd_tlm_server_chain.txt into config/tools/cmd_tlm_server/cmd_tlm_server_chain.txt
3.	Start CmdTlmServer with (probably create a modified launcher.txt and associated .bat file):
    * ```ruby CmdTlmServer --config cmd_tlm_server_chain.txt```


### Example CmdTlmServer Configuration for Child (cmd_tlm_server_chain.txt)

{% highlight bash %}
# Using this file WITH LOCALHOST requires changing the ports in system.txt
# Otherwise don't change the ports!

TITLE 'COSMOS Command and Telemetry Server - Chain Configuration'

# Don't log on the chained server
PACKET_LOG_WRITER DEFAULT packet_log_writer.rb nil false

# Replace localhost below with the IP Address of the main CmdTlmServer
# Update the target list below to the full list of targets in your system
# To make this child unable to send commands change the first 7779 to nil
INTERFACE CHAININT tcpip_client_interface.rb localhost 7779 7779 10 5 PREIDENTIFIED
  TARGET INST
  TARGET INST2
  TARGET EXAMPLE
  TARGET TEMPLATED
  TARGET COSMOS
{% endhighlight %}
