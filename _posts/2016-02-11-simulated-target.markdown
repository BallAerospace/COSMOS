---
layout: news_item
title: 'COSMOS Simulated Target'
date: 2016-02-11 00:00:00 -0700
author: jmthomas
categories: [post]
---

## Creating a COSMOS Simulated Target

Sometimes you have a need to create a simulated target in COSMOS. This simulated target is not a physical target producing data and accepting commands but a software target which generates data and sends it to COSMOS. This is exactly how the COSMOS Demo operates within the INST target that it creates. While this is a very full featured example its complexity can be a little overwhelming. In this post I'm going to break down a much simpler simulated target so you can create your own.

First of all create a new COSMOS target directory in config/targets. I called mine INST (instrument) to match the COSMOS demo. Create the 'cmd_tlm' and 'lib' subdirectories. For my demo I created a simple 'cmd.txt' file which contains a single command:

```
COMMAND INST SET_STATUS BIG_ENDIAN "Set status"
  APPEND_PARAMETER STATUS 0 STRING "STATUS" "Status"
    STATE "OK" "OK"
    STATE "ERROR" "ERROR"
```

I created a 'tlm.txt' file which contains two different telemetry packets:

```
TELEMETRY INST STATUS BIG_ENDIAN "Status from the instrument"
  APPEND_ID_ITEM ID 16 UINT 1 "Packet ID"
  APPEND_ITEM COUNTER 16 UINT "Packet counter"
  APPEND_ITEM STATUS 0 STRING "Most recent ASCIICMD string"
    STATE "OK" "OK"
    STATE "ERROR" "ERROR"

TELEMETRY INST DATA BIG_ENDIAN "Data from the instrument"
  APPEND_ID_ITEM ID 16 UINT 2 "Packet ID"
  APPEND_ITEM COUNTER 16 UINT "Packet counter"
  APPEND_ITEM TIMESEC 32 UINT "Seconds since epoch (January 1st, 1970, midnight)"
  APPEND_ITEM TIMEUS  32 UINT "Microseconds of second"
  APPEND_ITEM TEMP1 32 INT "Temperature #1"
    UNITS CELCIUS C
    FORMAT_STRING "%0.3f"
    LIMITS DEFAULT 1 ENABLED -80.0 -70.0 60.0 80.0 -20.0 20.0
```

The cmd_tlm_server.txt file is very simple:

```
INTERFACE INST_INT simulated_target_interface.rb sim_inst.rb
  TARGET INST
```

The real work is in implementing how your simulated target is going to behave. This is done in the lib/sim_inst.rb file. Note that whatever you name your simulated target file must match the last parameter of the INTERFACE in the cmd_tlm_server.rb as shown above.

I'll break down my sim_inst.rb piece by piece and then list it in its entirety. First you must inherit from the Cosmos::SimulatedTarget.

```ruby
require 'cosmos'
module Cosmos
  class SimInst < SimulatedTarget
```

Next you can initialize any of your packets in the initialize method. This is entirely optional but I show how to use the ```@tlm_packets``` hash to access all the defined packets. This hash is created automatically by the SimulatedTarget based on all the packets you have defined in your cmd_tlm/tlm.txt file. Note that there is NOT a corresponding ```@cmd_packets```.

```ruby
def initialize(target_name)
  super(target_name)

  # We grab the STATUS packet to set initial values
  packet = @tlm_packets['STATUS']
  packet.enable_method_missing # required to use packet.<item> = value
  packet.status = "NONE"
end
```

We then have to configure the telemetry packet rates of our target. That is, how fast do the packets get sent out. This is handled by implementing the ```set_rates``` method and by calling ```set_rate``` for each packet defined in your system. If you do not call ```set_rate``` the packet will not be send out periodically (which may be desirable for event based packets).

```ruby
def set_rates
  # The SimulatedTarget operates on a 101Hz clock
  # Thus the rates are determined by dividing this rate
  # by the set rate to get the output rate of the packet
  set_rate('STATUS', 100) # 100 / 100 = 1Hz
  set_rate('DATA', 10) # 100 / 10 = 10Hz
end
```

If your target will accept command you need to implemented the ```write(packet)``` method. My write method is simple in that I only have a single command that directly sets a value in one of my telemetry packets.

```ruby
def write(packet)
  # We directly set the telemetry value from the only command
  # If you have more than one command you'll need to switch
  # on the packet.packet_name to determine what command it is
  @tlm_packets['STATUS'].status = packet.read("status")
end
```

Your target must implement the ```read(count_100hz, time)``` method to return telemetry packets back to COSMOS. You'll call the ```get_pending_packets(count_100hz)``` method implemented by SimulatedTarget and then perform whatever operations you want on the packets before returning the array of packets back to COSMOS. Note my use of the ```cycle_tlm_item``` method to automatically cycle the telemetry item as each packet is sent out. This is used heavily in the COSMOS Demo.

```ruby
def read(count_100hz, time)
  # The SimulatedTarget implements get_pending_packets to return
  # packets at the correct time interval based on their rates
  pending_packets = get_pending_packets(count_100hz)

  pending_packets.each do |packet|
    case packet.packet_name
    when 'STATUS'
      packet.counter += 1
    when 'DATA'
      # This method in SimulatedTarget cycles the specified telemetry
      # point between the two given values by the given increment for
      # each packet sent out.
      cycle_tlm_item(packet, 'temp1', -95.0, 95.0, 1.0)

      packet.timesec = time.tv_sec
      packet.timeus  = time.tv_usec
      packet.counter += 1
    end
  end
  pending_packets
end
```

Hopefully that a little easier to understand than the full [COSMOS Demo](https://github.com/BallAerospace/COSMOS/tree/master/demo) which has much more complex command and telemetry definitions and simulated targets in order to better exercise the various COSMOS tools. While there are other ways to simulate COSMOS targets they can get you into trouble if you're not careful about properly cloning packets sending back updated data. Additionally, using the SimulatedTargetInterface in your Interface makes it very clear to other developers that this target is indeed simulated.

Without further ado, here is my sim_inst.rb in its entirety:

```ruby
require 'cosmos'
module Cosmos
  class SimInst < SimulatedTarget
    def initialize(target_name)
      super(target_name)

      # We grab the STATUS packet to set initial values
      packet = @tlm_packets['STATUS']
      packet.enable_method_missing # required to use packet.<item> = value
      packet.status = "NONE"
    end

    def set_rates
      # The SimulatedTarget operates on a 100Hz clock
      # Thus the rates are determined by dividing this rate
      # by the set rate to get the output rate of the packet
      set_rate('STATUS', 100) # 100 / 100 = 1Hz
      set_rate('DATA', 10) # 100 / 10 = 10Hz
    end

    def write(packet)
      # We directly set the telemetry value from the only command
      # If you have more than one command you'll need to switch
      # on the packet.packet_name to determine what command it is
      @tlm_packets['STATUS'].status = packet.read("status")
    end

    def read(count_100hz, time)
      # The SimulatedTarget implements get_pending_packets to return
      # packets at the correct time interval based on their rates
      pending_packets = get_pending_packets(count_100hz)

      pending_packets.each do |packet|
        case packet.packet_name
        when 'STATUS'
          packet.counter += 1
        when 'DATA'
          # This method in SimulatedTarget cycles the specified telemetry
          # point between the two given values by the given increment for
          # each packet sent out.
          cycle_tlm_item(packet, 'temp1', -95.0, 95.0, 1.0)

          packet.timesec = time.tv_sec
          packet.timeus  = time.tv_usec
          packet.counter += 1
        end
      end
      pending_packets
    end
  end
end
```

Happy simulated target programming!

