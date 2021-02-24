---
layout: news_item
title: "Protocol Rate"
date: 2020-03-17 08:00:00 -0700
author: jmthomas
categories: [post]
---

Protocols were introduced into COSMOS in version 4.0.0 and were previously discussed in [this post](/news/2019/06/05/protocols/). We recently had a question at Ball about how to reduce the telemetry rate of a high speed target so I thought I would walk through the problem and solution.

### The Problem

One COSMOS server was connected to a high speed telemetry target that was generating telemetry at 10Hz. Another COSMOS server was [chained](/docs/chaining/) to this and did not need this high speed data. How do you reduce the data rate coming into the chained server?

### The Solution

We can first model the chaining using the COSMOS demo. The format for the cmd_tlm_server.txt file is given in the [chaining documentation](https://cosmosrb.com/docs/chaining#example-cmdtlmserver-configuration-for-child-cmd_tlm_server_chaintxt) and already exists in the COSMOS demo. The demo also includes a deconflicting port definition file in system_alt_ports.txt. To start the two server instances from the command line we can type:

```
ruby demo\tools\CmdTlmServer
```

And in another terminal start the chained server:

```
ruby demo\tools\CmdTlmServer --system system_alt_ports.txt --config cmd_tlm_server_chain.txt
```

Now we need to implement a custom protocol to slow down the telemetry rate on the chained server. Note that the built-in protocols are fully described on the [Protocols](/docs/protocols) page and also mentioned on the [Interfaces](/docs/v4/interfaces#protocols) page.

### Custom Protocols

Let's assume we want to slow down the INST ADCS packet which the demo generates at 10Hz. First create a new file called config/targets/INST/lib/drop_protocol.rb. This protocol will drop data until we get the rate we want. It looks like this:

```
require 'cosmos/interfaces/protocols/protocol'
module Cosmos
  # Limit a specific packet by dropping packets
  class DropProtocol < Protocol
    def initialize(target_name, packet_name, drop, allow_empty_data = nil)
      super(allow_empty_data)
      System.telemetry.packet(target_name, packet_name)
      @target_name = target_name
      @packet_name = packet_name
      @drop = drop.to_i
      @count = 0
    end

    def read_packet(packet)
      target_names = nil
      target_names = @interface.target_names if @interface
      identified_packet = System.telemetry.identify_and_define_packet(packet, target_names)
      if identified_packet
        if identified_packet.target_name == @target_name && identified_packet.packet_name == @packet_name
          if @count < @drop
            @count += 1
            STDOUT.puts "DROP count:#{@count}" # Debugging statement
            return :STOP
          else
            @count = 0
            STDOUT.puts "SEND" # Debugging statement
          end
        end
      end
      return super(packet)
    end
  end
end
```

The constructor takes the target and packet names as well as the number of packets to drop. The read_packet method first identifies the incoming packet and then determines if it is the packet we're interested in. At that point I simply increment a counter until we get to the required number of drop packets and return :STOP to let COSMOS know not to return the packet. Once we want to actually send the packet we reset the counter and and simply fall through to super(packet).

Note I included some debugging lines to show how you can debug your own custom protocols. When you run the CmdTlmServer from the command line the STDOUT.puts will write to the terminal output.

Now we can add this protocol to the cmd_tlm_server_chain.txt definition as follows:

```
INTERFACE CHAININT tcpip_client_interface.rb localhost 7779 7779 10 5 PREIDENTIFIED
  TARGET INST
  TARGET INST2
  TARGET EXAMPLE
  TARGET TEMPLATED
  TARGET SYSTEM
  TARGET DART
  PROTOCOL READ DropProtocol INST ADCS 9 # Drop 9 ADCS packets to force 1Hz
```

Finally stop and relaunch the chained server:

```
ruby demo\tools\CmdTlmServer --system system_alt_ports.txt --config cmd_tlm_server_chain.txt
```

You should now see the following in your terminal output:

```
DROP count:1
DROP count:2
DROP count:3
DROP count:4
DROP count:5
DROP count:6
DROP count:7
DROP count:8
DROP count:9
SEND
DROP count:1
DROP count:2
DROP count:3
DROP count:4
DROP count:5
DROP count:6
DROP count:7
DROP count:8
DROP count:9
SEND
```

And the server "Tlm Packets" tab should show the ADCS count incrementing at 1Hz.
![Server Tlm Packets](/img/2020_03_17_server.png)<br/>
_Chained Server Tlm Packets tab_

This protocol is extremely simple but it accomplishes the task at hand. Remember protocols can be layered and operate in order so keeping them simple helps with debugging and reusability.

For example, to also reduce the rate of INST2 ADCS you'd simply add another PROTOCOL line to the cmd_tlm_server_chain.txt file:

```
INTERFACE CHAININT tcpip_client_interface.rb localhost 7779 7779 10 5 PREIDENTIFIED
  TARGET INST
  TARGET INST2
  TARGET EXAMPLE
  TARGET TEMPLATED
  TARGET SYSTEM
  TARGET DART
  PROTOCOL READ DropProtocol INST ADCS 9 # Drop 9 ADCS packets to force 1Hz
  PROTOCOL READ DropProtocol INST2 ADCS 9 # Drop 9 ADCS packets to force 1Hz
```

If you have a question, find a bug, or want a feature please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
