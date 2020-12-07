---
layout: docs
title: System Class
---

<div class="note">
  <h5>This documentation is for COSMOS Developers</h5>
  <p markdown="1">If you're simply trying to setup a COSMOS system you're probably looking for the [System Configuration](/docs/system) page. If you're trying to create a custom interface, background task, conversion, or build a custom tool then this is the right place.</p>
</div>

The System class is the primary entry point into the COSMOS framework. It provides access to the targets, commands, and telemetry. It also captures system wide configuration items such as the available ports and paths used by the system. The System class is primarily responsible for loading the system configuration file and creating all the Target instances. It also saves and restores configurations using a MD5 checksum over the entire configuration to detect changes.

The [system.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/system/system.rb) source code on Github.

## Programming System

Almost all custom COSMOS code needs to interact with System as it provides access to the COSMOS command and telemetry. The System clas is implemented as a [singleton](https://en.wikipedia.org/wiki/Singleton_pattern) which basically means there is only one instance of the class. This makes sense because COSMOS can only have a single instance which controls access to its internal state.

### System.commands

[System.commands](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/commands.rb) provides access to all the command definitions in the COSMOS system. The primary developer access methods are:

1. `System.commands.target_names` - Returns an array of strings containing the target names
2. `System.commands.all` - Returns a hash keyed by the target name with a hash of Packets as the value. The second hash is indentical to what is returned by System.commands.packets("TARGET").
3. `System.commands.packets("TARGET")` - Returns a Hash keyed by the packet name with the Packet instance as the value
4. `System.commands.packet("TARGET", "PACKET")` - Returns the given Packet instance
5. `System.commands.identify(data)` - Identify a raw buffer of data as a Packet and return the Packet instance.

Additional methods are available which are not as commonly used:

1. `System.commands.build_cmd("TARGET", "PACKET", params)` - Creates a Packet instance initialized with the values in the params hash.
2. `System.commands.format(packet)` - Returns a string which represents how to send this command in Script Runner. For example: Given a COSMOS start logging command instance it returns "cmd('COSMOS STARTLOGGING')"
3. `System.commands.cmd_pkt_hazardous?(command)` - Returns an array where the first boolean value indicates whether the given command is hazardous or not. If the first value is true (hazardous), the second value is a string with information about the hazard.
4. `System.commands.cmd_hazardous?("TARGET", "PACKET", params)` - Returns the same data as cmd_pkt_hazardous? above.

Other methods are available but generally should not be used by developers.

#### Command Sender Example

COSMOS uses System.commands in many of its own applications. Let's see how it's used in the [Command Sender](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/tools/cmd_sender/cmd_sender.rb). In the `update_targets` method it uses System.commands.target_names to populate the target drop down selection.

```ruby
def update_targets
  @target_select.clearItems()
  target_names = System.commands.target_names
  ... # Code to check for hidden commands
  target_names.each do |target_name|
    @target_select.addItem(target_name)
  end
end
```

Once it checks for hidden commands it adds all the target names to the drop down selection in the tool. In the same way the `update_commands` method accesses System.commands.packets to update the packet drop down selection.

```ruby
def update_commands
  @cmd_select.clearItems()
  target_name = @target_select.text
  if target_name
    commands = System.commands.packets(@target_select.text)
    command_names = []
    commands.each do |command_name, command|
      command_names << command_name unless command.hidden
    end
    command_names.sort!
    command_names.each do |command_name|
      @cmd_select.addItem(command_name)
    end
  end
end
```

Later in the `update_cmd_params` method we access the individual command to grab the command parameters:

```ruby
def update_cmd_params(ignored_toggle = nil)
  ...
  target_name = @target_select.text
  target = System.targets[target_name]
  packet_name = @cmd_select.text
  if target_name and packet_name
    packet = System.commands.packet(target_name, packet_name)
    packet_items = packet.sorted_items
    ...
  end
end
```

If the target and packet selections have been set, we grab the specified packet using System.commands.packet and then have access to the packet items through packet.sorted_items.

#### Interface Example

Sometimes when you're creating a custom interface you want to respond to a COSMOS command within the interface itself and not forward on that command to the target. In the interface's connect method you can get a handle to the command you're interested in.

```ruby
require 'cosmos/interfaces/tcpip_client_interface'
module Cosmos
  class TestInterface < Interface
    def connect
      super()
      @configure = System.commands.packet(@target_names[0], 'CONFIGURE')
    end
  end
end
```

In this example, we inherit from the COSMOS TcpipClientInterface. We grab a handle to the 'CONFIGURE' packet by using the @target_names array. This array is populated by the COSMOS Server when the target is assigned. This allows you to dynamically get your target name since targets can be renamed by the server.

In the interface's write method we can check for the previously saved packet.

```ruby
# Defined inside the TestInterface class
def write(packet)
  if @configure.identify?(packet.buffer)
    value = packet.read("VALUE") # Do something ...
  else
    super(packet) # Allow TcpipClientInterface to write the packet
  end
end
```

We use the Packet class's identify? method to determine if the packet passed in is the one we're interested in. Then we can read values from the packet and take whatever actions we want. If this is not the 'CONFIGURE' packet then we call super(packet) to allow the TcpipClientInterface logic to send the packet to the target.

### System.telemetry

[System.telemetry](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/telemetry.rb) provides access to all the telemetry definitions in the COSMOS system. The primary developer access methods are:

1. `System.telemetry.target_names` - Returns an array of strings containing the target names
2. `System.telemetry.all` - Returns a hash keyed by the target name with a hash of Packets as the value. The second hash is indentical to what is returned by System.telemetry.packets("TARGET").
3. `System.telemetry.packets("TARGET")` - Returns a Hash keyed by the packet name with the Packet instance as the value
4. `System.telemetry.packet("TARGET", "PACKET")` - Returns the given Packet instance
5. `System.telemetry.items("TARGET", "PACKET")` - Returns an array of PacketItem instances for the given target and packet
6. `System.telemetry.value("TARGET", "PACKET", "ITEM")` - Returns the telemetry value. Note this can take a fourth parameter indicating how to format the value.
7. `System.telemetry.identify!(data)` - Identify a raw buffer of data as a Packet and return the Packet instance.

Additional methods are available which are not as commonly used:

1. `System.telemetry.item_names("TARGET", "PACKET")` - Returns an array of item name strings for the given target and packet
2. `System.telemetry.packet_and_item("TARGET", "PACKET", "ITEM")` - Returns an array where the first item is the Packet instance and second item is the PacketItem instance
3. `System.telemetry.set_value("TARGET", "PACKET", "ITEM", value)` - Sets a telemetry value in a packet. Note that as soon as a new packet is received from the target this value will be overwritten.
4. `System.telemetry.latest_packets("TARGET", "ITEM")` - Returns an array of Packet instances with the specified target and item
5. `System.telemetry.values_and_limits_states([["TARGET", "PACKET", "ITEM"], ... ])` - Returns an array of three arrays: The first contains the item(s) value, the second the item(s) limits state, and the third the item(s) limits settings.
6. `System.telemetry.stale` - Returns an array of all stale Packet instances. Packets are defined as stale if they haven't been received for System.staleness_seconds.

Other methods are available but generally are not used by developers.

#### Packet Viewer Example

COSMOS uses System.telemetry in many of its own applications. Let's see how it's used in the [Packet Viewer](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/tools/packet_viewer/packet_viewer.rb). In the `update_targets` method it uses System.telemetry.target_names and System.telemetry.packets.

```ruby
def update_targets
  @target_select.clearItems

  System.telemetry.target_names.each do |target_name|
    packets = System.telemetry.packets(target_name)
    has_non_hidden = false
    packets.each do |packet_name, packet|
      next if packet.hidden
      has_non_hidden = true
      break
    end
    @target_select.addItem(target_name) if has_non_hidden
  end
end
```

First we grab all the target names and then grab all the packets for each target. This is done to filter out targets in which all packets are hidden. Once it checks for hidden packets it adds all the target names to the drop down selection in the tool. In the same way the `update_packets` method access System.telemetry.packets to update the packet drop down selection.

Later in the `update_tlm_items` method we call System.telemetry.items to get the individual packet items.

```ruby
def update_tlm_items(featured_item_name = nil)
  target_name = @target_select.text
  packet_name = @packet_select.text
  ...
    System.telemetry.items(target_name, packet_name).each do |item|
      tlm_items << [item.name, item.states, item.description, item.data_type == :DERIVED]
    end
  ...
end
```

Once we have the items we call individual [PacketItem](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/packet_item.rb) methods to get the name, states, description, and data type.

#### Interface Example

Sometimes you want to create a fake interface which returns internally generated data instead of returning data from an external device. To do this you need to populate the packets and return them from the interface's read method. In the interface's initialize method we setup an array to store the packet instances. In the connect method We grab a handle to all the target's packets by using the @target_names array. This array is populated by the COSMOS Server when the target is assigned. This allows you to dynamically get your target name since targets can be renamed by the server.

```ruby
require 'cosmos/interfaces/interface'
module Cosmos
  class TestInterface < Interface
    def initialize
      super()
      @pending_packets = Array.new
      @next_read_time = nil
    end

    def connect
      # Note we do NOT call super() here because the Interface base class simply
      # raises an exception. This forces us to reimplement it in derived classes.
      @next_read_time = Time.now
      @connected = true
      @packets = System.telemetry.packets(@target_names[0])
    end

    def connected?
      # No super (see connect)
      @connected
    end

    def disconnect
      # No super (see connect)
      @connected = false
    end
  end
end
```

In the interface's read method we both populate the packets and return them.

```ruby
# Defined inside the TestInterface class
def read(packet)
  if not @pending_packets.empty?
    @read_count += 1
    # Pop off the packet instance and clone it so it is standalone
    return @pending_packets.pop.clone
  end

  # Calculate time to sleep to make ticks 1s apart
  delta = @next_tick_time - Time.now
  sleep(delta) if delta > 0.0 # sleep up to 1s
  @next_tick_time += 1

  @packets.each do |name, packet|
    # Populate your packets with calculated values
    packet.write("DATA", "Sample data")
    @pending_packets.push(packet)
  end

  @read_count += 1
  @pending_packets.pop.clone # Return the first pending packet
end
```

The COSMOS Server will call the interface call method as rapidly as it can. The read method must return a Packet instance or nil to disconnect. Initially we check the pending_packets array for available packets and return them. Once the pending_packets array has been emptied we sleep a second to allow our interface to operate at 1Hz. An exercise left to the reader would be to pass the rate to the interface and use that. Next we iterate through the previously stored packet list, populate any values we want, and push the packets back on the pending_packets array. Finally we pop off the first packet on the pending packets array.

### System.limits

[System.limits](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/limits.rb) provides access to all the limits definitions in the COSMOS system. The primary developer access methods are:

1. `System.limits.sets ` - Returns an array of symbols defining the system limits sets
2. `System.limits.out_of_limits` - Returns an array indicating all items that are out of limits. The array values are arrays formatted as ["TARGET", "PACKET", "ITEM", :LIMIT_STATE]. The last item is a symbol indicating the current limit state.
3. `System.limits.overall_limits_state` - Returns a symbol indicating the current overall limits state.
4. `System.limits.groups` - Returns a hash whose keys are the string limit group name and values are an array. Each item in the array is formatted as ["TARGET", "PACKET", "ITEM"] and thus identifies all the items in that particular limits group.
5. `System.limits.enable_group("GROUP")` - Enable a limits group
6. `System.limits.disable_group("GROUP")` - Disable a limits group

Additional methods are available which are not as commonly used:

1. `System.limits.enabled?("TARGET", "PACKET", "ITEM")` - Returns whether limits are enabled for the given item
2. `System.limits.enable("TARGET", "PACKET", "ITEM")` - Enable limit checking for the given item
3. `System.limits.disable("TARGET", "PACKET", "ITEM")` - Disable limit checking for the given item
4. `System.limits.get("TARGET", "PACKET", "ITEM")` - Return information about an items limits. The values are returned in an array as [limits_set, persistence, enabled, red_low, yellow_low, red_high, yellow_high, green_low (optional), green_high (optional)]

Other methods are available but generally are not used by developers.

#### Example

In general you should use the CmdTlmServer [API](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/tools/cmd_tlm_server/api.rb) methods instead of the System.limits methods directly.

### System.ports

System.ports returns a hash keyed by the name of the port with the value the port number. This hash will always contain the known COSMOS ports of 'CTS_API', 'TLMVIEWER_API', 'CTS_PREIDENTIFIED', and 'CTS_CMD_ROUTER'.

### System.paths

System.paths returns a hash keyed by the name of the path with the value the file system path. This hash typically contains the known COSMOS paths of 'LOGS', 'TMP', 'SAVED_CONFIG', 'TABLES', 'HANDBOOKS', 'PROCEDURES'.

### System.targets

System.targets returns a hash keyed by the name of the target with [Target](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/system/target.rb) instance values. The Target instance has instance variables which return useful information about the target. The most frequently used are:

1. name - Name of the target
2. ignored_parameters - Array of parameters which should be ignored by various tools
3. ignored_items - Array of items which should be ignored by various tools
4. interface - Interface instance which is mapped to this target
5. cmd_cnt - The number of command packets sent to this target
6. tlm_cnt - The number of telemetry packets received from this target

Other methods are available but generally are not used by developers.
