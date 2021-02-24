---
layout: news_item
title: "Identifying Packets"
date: 2020-03-24 08:00:00 -0700
author: jmthomas
categories: [post]
---

COSMOS goes through a multi-stage process to turn raw bits into identified [Packets](/docs/v4/packet-class/) belonging to a target. Understanding these steps are helpful when writing your own custom [interface](/docs/v4/interfaces/).

### Packet Identification Process

The [CmdTlmServer](/docs/tools#command-and-telemetry-server) creates a new thread for each interface that was defined by the configuration text files. It calls connect() and then continuously calls the interface's read() method which returns a packet. Typically the packets are unidentified meaning they don't have an assigned target or packet name. At that point the interface thread loops through all the targets assigned to the interface to identify the packet. More on that later.

The implementation of the interface's read() method first calls read_interface() which subclasses must implement to return raw data. Once it has the raw data, read_interface() should call read_interface_base(data) which updates internal counters. The read() method then loops through all the defined [protocols](/docs/protocols/) for that interface which can add or subtract data and/or modify the packet. Ultimately a [Packet](/docs/v4/packet-class/) instance is returned.

The packet identification process is implemented in [System.telemetry.identify!()](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/telemetry.rb#L252). The identify!() method loops through all the given targets looking to identify the data. There are two ways to identify a packet. The new way, which was implemented in [COSMOS 4.4](/news/2019/06/28/cosmos-4-4-0-released/), utilizes a lookup hash which is created for each target. This requires that every packet in the target has the same ID_ITEMS (same type, size, location) defined for each packet which is generally good practice. If you have hundreds of small packets associated with a single target it's especially important to utilize this new lookup method. The old identification method is still available if you put TLM_UNIQUE_ID_MODE in the target's target.txt file. In this mode, each packet's ID_ITEMS are read and individually checked for a match.

### Custom Interfaces

The implication of this process for custom interfaces is how and when packets are identified. If your custom interface can determine the target, you would want to identify the packet before returning it to save processing time. This may also be required if you map multiple targets to a single interface and have identification collisions. Identification collisions occur if two packets in different targets with the same ID_ITEMS are mapped to the same interface. In this case a custom interface would first have to properly identify the target and then override the read() method to identify the packet before returning it.

An example of a custom interface implementing this might look something like this:

```
require 'cosmos/interfaces/interface'
module Cosmos
  class MyInterface < Interface
    # ... various other methods

    def read_interface
      # Implement something to get the raw data and return it
      # ...
      # This is probably where you determine which target the data belongs to
      @target_name = "TARGETX"
      read_interface_base(data)
      return data
    end

    def read
      packet = super() # Ensure the base class implementation is called
      # Call the identify! method to identify the packet using the given target
      return System.telemetry.identify!(packet.buffer, [@target_name]).dup # Copy the identified packet before returning it
    end
  end
end
```

At this point the interface thread will receive an identified packet and can quickly update the current value table with the packet data.

If you have a question, find a bug, or want a feature please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
