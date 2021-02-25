---
layout: docs
title: Packet Class
---

<div class="note">
  <h5>This documentation is for COSMOS Developers</h5>
  <p markdown="1">If you're simply trying to setup a COSMOS system you're probably looking for the [System Configuration](/docs/v4/system) page. If you're trying to create a custom interface, background task, conversion, or build a custom tool then this is the right place.</p>
</div>

The Packet class is used to access the command and telemetry packet instances. The primary way to access Packet instances is through the [System](/docs/v4/system-class) class. The Packet class provides access to information about the packet as well as all the packet items.

The [packet.rb](https://github.com/BallAerospace/COSMOS/blob/cosmos4/lib/cosmos/packets/packet.rb) source code on Github.

## Programming Packet

Most custom COSMOS code needs to interact with Packet as it provides access to the internal values defined by your command and telemetry definitions. Packet inherits from Structure which it uses to provide some of the lower level functionality associated with reading and writing packets. Typically you shouldn't need to directly use any of the Structure methods. Packet instances can be either commands or telemetry and there is no way to directly know whether a packet instance is a command or telemetry packet. However, since you're typically getting packet instances through `System.commands` or `System.telemetry` this is rarely an issue in practice.

### Packet Instance Variables

Packet defines a large number of instance variables that provide information about the packet. The most commonly used are as follows:

1. `target_name` - Target name as a string
1. `packet_name` - Packet name as a string
1. `description` - Packet description as a string
1. `received_time` - Time object representing when this packet was received by the COSMOS Server
1. `received_count` - Number of times this packet was received by the COSMOS Server
1. `items` - Hash of all the [items](/docs/v4/packet-item-class) keyed by the uppercase item name
1. `sorted_items` Array of all the [items](/docs/v4/packet-item-class) sorted by bit_offset

If you're dealing with a Command packet instance there are additional instance variables that are useful:

1. `hazardous` - Boolean indicating whether the command is hazardous (see [hazardous](/docs/v4/command#hazardous))
1. `hazardous_description` - String description of why the packet is hazardous
1. `hidden` - Boolean indicating whether this packet is hidden (see [hidden](/docs/v4/command#hidden))
1. `disabled` - Boolean indicating whether this packet is disabled (see [disabled](/docs/v4/command#disabled))

### Packet Methods

#### read

Read is used to retrieve packet values. The parameters are as follows:

| Parameter  | Description                                                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------- |
| name       | Name of the item to read                                                                                          |
| value_type | How the value should be read. Must be one of :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS. Defaults to :CONVERTED |
| buffer     | Raw data buffer to read the value from (defaults to the current packet)                                           |

Example:

```ruby
value = packet.read('ITEM') # Converted value (default)
value = packet.read("ITEM", :RAW) # Raw value (no COSMOS conversions applied)
value = packet.read("ITEM", :FORMATTED) # String formatted value
value = packet.read("ITEM", :WITH_UNITS) # String formatted value with units
value = packet.read("ITEM", :CONVERTED, buffer) # Read the value from the passed buffer (RARELY USED)
```

First a comment about syntax. The first parameter in the read method is a string which in Ruby can be either single or double quotes. The second parameter is a Ruby Symbol which is similar to a string but is prefixed with a colon.

Note that there are four different ways to read a packet value as indicated above in the value_type description. :RAW means to return the value defined at that location in the packet without applying any COSMOS conversions or STATE names. :CONVERTED (the default) means to apply COSMOS conversions and any defined State values (see [STATE](/docs/v4/telemetry#state)). :FORMATTED means to apply any format strings on the packet item (see [FORMAT_STRING](/docs/v4/telemetry#format_string)) and return the resulting string. Note that :FORMATTED always returns a STRING even if there is no formatting being applied. This is distinct from :RAW and :CONVERTED which return a value of the type you specify in the packet definition. Finally :WITH_UNITS applies any units (see [UNITS](/docs/v4/telemetry#units)) to the formatted value and again returns a string value.

The final parameter is buffer. Typically you will just leave this off and write to the buffer contained by the current packet instance. However, if you have an unidentified buffer of data that you believe represents a particular packet instance, you can pass that into read.

#### write

Write is used to set packet values. Keep in mind that if you're trying to write values to a packet which is part of a live telemtry stream, your value will be overwritten by the interface and never appear. The parameters are as follows:

| Parameter  | Description                                                                                |
| ---------- | ------------------------------------------------------------------------------------------ |
| name       | Name of the item to read                                                                   |
| value      | Value to write                                                                             |
| value_type | How the value should be written. Must be either :RAW or :CONVERTED. Defaults to :CONVERTED |
| buffer     | Raw data buffer to read the value from (defaults to the current packet)                    |

Example:

```ruby
packet.write('ITEM', value) # Converted value
packet.write("ITEM", value, :RAW) # Raw value
```

See [read](/docs/v4/packet-class#read) for a note about the syntax and what value_type means.

There are a few gotchas associated with writing a value into a packet. If you're writing a value marked as STRING then you can pass almost any value you want as Ruby will automatically convert it into a string. If the packet item has any [write conversions](/docs/v4/telemetry#write_conversion) then using the :RAW value_type will bypass that conversion. For example:

```ruby
packet.write('STRING_ITEM', 10) # 10 will be converted to '10' automatically
packet.write("STRING_ITEM", 12.5, :RAW) # 12.5 will be converted to '12.5'
```

If you're writing into an integer or float value you must pass in something that can be converted to that value. This means that Strings will not work. However, float values work for integers (they are truncated) and integers work for floats. For example:

```ruby
packet.write("INT_ITEM", "STRING") #=> ArgumentError : invalid value for Integer(): "STRING"
packet.write("INT_ITEM", 10.5) #=> packet.read("INT_ITEM") returns 10
packet.write("FLOAT_ITEM", 10) #=> packet.read("FLOAT_ITEM") returns 10.0
```

If there are no [write conversions](/docs/v4/telemetry#write_conversion) or [states](/docs/v4/telemetry#state) defined on the telemetry item then writing with :RAW or :CONVERTED will be equivalent.

Definition File:

```bash
APPEND_ITEM INT_ITEM_WITH_STATES 32 UINT "Item"
  STATE OFF 0
  STATE ON 1
```

Example:

```ruby
packet.write("INT_ITEM_WITH_STATES", "ON") # Writes using the "ON" state value
packet.read("INT_ITEM_WITH_STATES", :RAW) #=> returns 1
packet.write("INT_ITEM_WITH_STATES", 0) # Writes the value 0
packet.read("INT_ITEM_WITH_STATES") #=> returns "OFF"
```

#### read_all

Read all is used to retrieve all the packet values. The parameters are as follows:

| Parameter  | Description                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------ |
| value_type | How the values should be read. Must be one of :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS. Defaults to :CONVERTED |
| buffer     | Raw data buffer to read the value from (defaults to the current packet)                                            |

Example:

```ruby
values = packet.read_all() # Converted values (default)
values = packet.read_all(:RAW) # Raw values (no COSMOS conversions applied)
values = packet.read_all(:FORMATTED) # String formatted values
values = packet.read_all(:WITH_UNITS) # String formatted values with units
```

The return result is an array of arrays. Each internal array has two elements, the item name and value. The overall structure is as follows: [[item name, item value], [...], ...].

#### length

Length returns the size of the internal packet buffer.

#### buffer

Buffer provides access to the internal packet buffer. Note that by default it returns a copy of the internal buffer so any modifications do NOT affect the packet.

| Parameter | Description                                               |
| --------- | --------------------------------------------------------- |
| copy      | Whether to return a copy of the buffer. Defaults to true. |

#### buffer=

Buffer= sets the internal packet buffer. Note that it copies the passed in buffer so any future modifications to the passed in buffer do NOT affect the packet.

| Parameter | Description                                                 |
| --------- | ----------------------------------------------------------- |
| buffer    | String containing the raw binary buffer to back this packet |

#### clone and dup

Clone and dup make a copy of the packet instance with a new internal buffer. Thus the newly cloned packet can modify its values independently of the previous packet.

#### identified?

Returns whether this packet has been identified which means it has its internal target_name and packet_name set. Initially when data is read from an interface a nil packet is created like so: `Packet.new(nil, nil, :BIG_ENDIAN, nil, data)`. The packet then needs to be identified by calling identify?.

#### identify?

Returns whether the buffer of data parameter represents this packet. It does this by iterating over all the packet items that were created with an ID value (see [id_parameter](/docs/v4/command#id_parameter) and [id_item](/docs/v4/telemetry#id_item)) and checking whether the ID values are present in the buffer.

| Parameter | Description                                                        |
| --------- | ------------------------------------------------------------------ |
| buffer    | String containing the raw binary buffer to identify as this packet |

#### restore_defaults

Set all items in the packet to their default values. This only makes sense for command packets which define default values for parameters.

| Parameter       | Description                                                                 |
| --------------- | --------------------------------------------------------------------------- |
| buffer          | Raw data buffer to write default values to (defaults to the current packet) |
| skip_item_names | Array of item names to skip when setting defaults                           |

Definition File:

```bash
COMMAND TGT PKT BIG_ENDIAN "Packet"
  APPEND_PARAMETER VALUE 32 UINT MIN MAX 10 "Value"
  APPEND_PARAMETER OTHER 32 UINT MIN MAX 1 "Other"
```

Example:

```ruby
command = System.commands.packet("TGT", "PKT")
command.read("VALUE") #=> Returns 0
command.restore_defaults
command.read("VALUE") #=> Returns 10
command.read("OTHER") #=> Returns 1
command.write("VALUE", 0)
command.write("OTHER", 0)
# Since we want to use the skip_item_names parameter we have to pass in the buffer
# Since we want to directly modify this packet buffer we use command.buffer(false)
# because the default command.buffer returns a COPY of the internal buffer
command.restore_defaults(command.buffer(false), ['OTHER'])
command.read("VALUE") #=> Returns 10 (default)
command.read("OTHER") #=> Returns 0 (not default)
```

#### out_of_limits

Out of limits returns an array of arrays indicating all the items in the packet that are out of limits. The internal array has four elements: target name, packet name, item name, and the item limits state. The out of limits item states are :RED_HIGH, :YELLOW_HIGH, :RED_LOW, or :YELLOW_LOW.

Example:

```ruby
packet = System.telemetry.packet("TGT", "PKT")
packet.out_of_limits.each do |tgt, pkt, item, state|
  puts "tgt:#{tgt} pkt:#{pkt} item:#{item} state:#{state}"
end
```

Note that this code only works as expected inside the COSMOS Server, for example in a background task. If this code is executed in Script Runner you will retrieve a local copy of the packet which will not have any out of limits items.
