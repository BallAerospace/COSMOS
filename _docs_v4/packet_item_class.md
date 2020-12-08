---
layout: docs
title: PacketItem Class
---

<div class="note">
  <h5>This documentation is for COSMOS Developers</h5>
  <p markdown="1">If you're simply trying to setup a COSMOS system you're probably looking for the [System Configuration](/docs/system) page. If you're trying to create a custom interface, background task, conversion, or build a custom tool then this is the right place.</p>
</div>

The PacketItem class is used to access an individual item within a [Packet](/docs/packet_class). The primary way to access Packet instances is through the [System](/docs/system_class) class. The PacketItem class provides access to information about the item like its location in the packet, type, endianness, conversions, states, etc.

The [packet_item.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/packet_item.rb) source code on Github.

## Programming PacketItem

Custom COSMOS code may need to interact with PacketItem as it provides access to the individual item defined by your command and telemetry definitions. PacketItem inherits from StructureItem which it uses to provide some of the lower level functionality associated with defining an item. Typically you're directly using the PacketItem class. PacketItem instances can be either command items or telemetry items and there is no way to directly know whether an instance is from a command or telemetry packet. However, since you're typically getting packet instances through `System.commands` or `System.telemetry` this is rarely an issue in practice.

### PacketItem Instance Variables

PacketItem defines a large number of instance variables that provide information about the packet. The most commonly used are as follows:

1. `name` - Item name as a string
1. `description` - Description of the item
1. `bit_offset` - Where in the binary buffer the item exists
1. `bit_size` - The number of bites which represent the item in the buffer
1. `data_type` - Data type which can be :INT, :UINT, :FLOAT, :STRING, :BLOCK, or :DERIVED. See [Command](/docs/command) or [Telemetry](/docs/telemetry) for a description of the types.
1. `endianness` - Endianness of the item which is either :BIG_ENDIAN or :LITTLE_ENDIAN.
1. `read_conversion` - Conversion applied when reading the item (typically applied to telemetry items)
1. `write_conversion` - Conversion applied when writing the item (typically applied to command items)
1. `states` - States used to convert a numeric value to a string
1. `units` - Abbreviated units of the item, e.g. "V"
1. `range` - Valid range of values (nil for :STRING or :BLOCK types, only applies to command items)
1. `id_value` - Value used to identify a packet
1. `default` - Default value for the item (only applies to command items)
1. `limits` - Limits for the item (only applies to telemetry items)

### PacketItem Methods

The only methods most developers will use on PacketItem instances are the accessor methods that access the instance variables defined above. There are also corresponding setter methods that set all the above variables.

Command Example:

```ruby
System.commands.each do |packet|
  packet.sorted_items.each do |item|
    puts "#{item.name}::#{item.description} range:#{item.range} default:#{item.default}"
  end
end
```

Telemetry Example:

```ruby
System.telemetry.each do |packet|
  packet.sorted_items.each do |item|
    puts "#{item.name}::#{item.description} states:#{item.states} limits:#{item.limits}"
  end
end
```

Note that once you have a Packet instance you can access the items using the following methods:

#### packet.get_item

Returns an individual item by name

```ruby
item = packet.get_item("ITEM_NAME")
```

#### packet.items

Returns a hash of items keyed by the item name

```ruby
packet.items.each do |name, item|
  puts "item:#{name}: #{item.description}"
end
```

#### packet.sorted_items

Returns an array of items sorted by the bit_offset

```ruby
packet.sorted_items.each do |item|
  puts "item:#{item.name}: #{item.bit_offset}"
end
```

#### packet.id_items

Returns an array of all the ID items defined in the packet. ID items are defined by the [ID_PARAMETER](/docs/command/#id_parameter) keyword in commands and the [ID_ITEM](/docs/telemetry/#id_item) keyword in telemetry (and their associated APPEND keywords).

```ruby
packet.id_items.each do |item|
  puts "item:#{item.name}: #{item.id_value}"
end
```

#### packet.limits_items

Returns an array of all the items defined in the packet with limits. Limits items are defined by the [LIMITS](/docs/telemetry/#limits) keyword in telemetry items.

```ruby
packet.limits_items.each do |item|
  puts "item:#{item.name}: #{item.limits}"
end
```
