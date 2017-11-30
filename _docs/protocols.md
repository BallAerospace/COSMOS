---
layout: docs
title: Protocol Configuration
permalink: /docs/protocols/
toc: true
---
Protocols process data on behalf of an Interface. They can modify the data being written, data being read, or both. Protocols can be layered and will be processed in order. For example, if you have a low level encryption layer that must be first removed before processing a higher level buffer length protocol. 

Protocols are typically used to define the logic to deliniate packets and manipulate data as it written to and read from Interfaces. COSMOS includes Interfaces for TCP/IP Client, TCP/IP Server, Udp Client / Server, and Serial connections. For 99% of use cases these Interfaces should not require any changes as they universally handle the low level details of reading and writing from these types of connections.  All unique behaviour should now be defined in Protocols as of COSMOS 4.0.0. (Note in versions of COSMOS before COSMOS 4, Interfaces supported an more limited system called Stream Protocols that only allowed one Protocol per Interface and were more coupled to the Interface. This document refers to protocols in COSMOS 4+)

At a minimum, any byte stream based Interface will require a Protocol to deliniate packets.  TCP/IP and Serial are examples of byte stream based Interfaces.  A byte stream is just that, a stream of bytes, you have to have some way to know where packets begin and end within the stream.  

TCP/IP is a friendly byte stream.  Unless you are dealing with a very poorly written system, the first byte received on a TCP/IP connection will always be the start of a packet.  Also, TCP/IP is a reliable connection in that it ensures that all data is received in the correct order, that no data is lost, and that the data is not corrupted (TCP/IP is protected by a CRC32 - Not perfect, but pretty good for avoiding unrecognized data corruption).

Serial is not nearly as friendly of a byte stream. With serial connections it is very likely that when you open a serial port and start receiving data, that you will receive the middle of a message.  (This is only not the case if interfacing with a system that only writes to the serial port in response to a command). For this reason, sync patterns are highly beneficial for serial interfaces. Additionally, serial interfaces may or may not use some method to protect against unrecognized data corruption (Checksums, CRCs, etc.)  

UDP is an inherently packet based connection.  If you read from a UDP socket, you will always receive back an entire packet.  The best UDP based Protocols take advantage of this fact.  Some try to make UDP act like a byte stream, but in my opinion this is a misuse of the protocol because it is highly likely that you will lose data and have no way to recover.

## Packet Deliniation Protocols
COSMOS provides the following packet deliniation protocols: Burst, Fixed, Length, Preidentified, Template, and Terminated.  Each of these protocols has the primary purpose of seperating out packets from a byte stream.

### Burst Protocol
The Burst Protocol simply reads as much data as it can from the interface before returning the data as a COSMOS Packet (It returns a packet for each set of data read). This Protocol relies on regular bursts of data delimited by time and thus is not very robust. However it can utilize a sync pattern which does allow it to re-sync if necessary. It can also discard bytes from the incoming data to remove the sync pattern. Finally it can add sync patterns to data being written out of the Interface.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned | No | nil (no sync pattern)
| Fill Fields | Whether or not to fill in the sync pattern on outgoing packets | No | false
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### Fixed Protocol
The Fixed Protocol reads a preset minimum amount of data which is necessary to properly identify all the defined packets using the interface. It then identifies the packet and proceeds to read as much data from the interface as necessary to create the packet which it then returns. This protocol relies on all the packets on the interface being fixed in length. For example, all the packets using the interface are a fixed size and contain a simple header with a 32 bit sync pattern followed by a 16 bit ID. The Fixed Protocol would elegantly handle this case with a minimum read size of 6 bytes. The Fixed Protocol also supports a sync pattern, discarding leading bytes, and filling the sync pattern similar to the Burst Protocol.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Minimum ID Size | The minimum amount of bytes needed to identify a packet. All the packet definitions must declare their ID_ITEM(s) within this given amount of bytes. | Yes |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Telemetry | Whether the data is telemetry | No | true (false means command)
| Fill Fields | Whether or not to fill in the sync pattern on outgoing packets | No | false
| Unknown Raise | Whether or not to raise an exception for an unknown packet | No | false
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### Length Protocol
The Length Protocol depends on a length field at a fixed location in the defined packets using the interface. It then reads enough data to grab the length field, decodes it, and reads the remaining length of the packet. For example, all the packets using the interface contain a CCSDS header with a length field. The Length Protocol can be set up to handle the length field and even the correct offset the CCSDS header uses. The Length Protocol also supports a sync pattern, discarding leading bytes, and filling the length and sync pattern similar to the Burst Protocol.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Length Bit Offset | The bit offset from the start of the packet to the length field. Every packet using this interface must have the same structure such that the length field is the same size at the same location. Be sure to account for the length of the Sync Pattern in this value (if present). | No | 0 bits
| Length Bit Size | The size in bits of the length field | No | 16 bits
| Length Value Offset | The offset to apply to the length field value. The actual value of the length field plus this offset should equal the exact number of bytes required to read all data for the packet (including the length field itself, sync pattern, etc).  For example if the length field indicates packet length minus one, this value should be one. Be sure to account for the length of the Sync Pattern in this value (if present). | No | 0
| Bytes per Count | The number of bytes per each length field 'count'. This is used if the units of the length field is something other than bytes, for example if the length field count is in words. | No | 1 byte
| Length Endianness | The endianness of the length field. Must be either 'BIG_ENDIAN' or 'LITTLE_ENDIAN'. | No | 'BIG_ENDIAN'
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes including the sync pattern if the sync pattern is being used. Discarding is one of the very last steps so any size and offsets above need to account for all the data before discarding. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Max Length | The maximum allowed value in the length field | No | nil (no maximum length)
| Fill Length and Sync Pattern | Setting this flag to true causes the length field and sync pattern (if present) to be filled automatically on outgoing packets. | No | false
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### Terminated Protocol
The Terminated Protocol delineates packets using termination characters found at the end of every packet. It continuously reads data until the termination characters are found at which point it returns the packet data. For example, all the packets using the interface are followed by 0xABCD. This data can either be a part of each packet that is kept or something which is known only by the Terminated Protocol and simply thrown away.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Write Termination Characters | The data to write after writing a command packet. Given as a hex string such as 0xABCD. | Yes |
| Read Termination Characters | The characters which delineate the end of a telemetry packet. Given as a hex string such as 0xABCD. | Yes |
| Strip Read Termination | Whether to remove the read termination characters before returning the telemetry packet | No | true
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes including the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Fill Fields | Whether or not to fill in the sync pattern on outgoing packets | No | false
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### Preidentified Protocol
The Preidentified Protocol is used internally by the COSMOS Command and Telemetry Server only and delineates packets using a custom COSMOS header. This Protocol is configured by default on port 7779 and is created by the Command and Telemetry Server to allow tools to connect and receive the entire packet stream. The Telemetry Grapher uses this port to receive all the packets following through the Command and Telemetry Server in case any need to be graphed.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found AFTER the sync pattern will be returned. The sync pattern itself is discarded. | No | nil (no sync pattern)
| Max Length | The maximum allowed value in the length field | No | nil (no maximum length)
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### Template Protocol

The Template Protocol works much like the Terminated Protocol except it designed for text-based command and response type interfaces such as SCPI (Standard Commands for Programmable Instruments).  It delineates packets in the same way as the Terminated Protocol except each packet is referred to as a line (because each usually contains a line of text). For outgoing packets a CMD_TEMPLATE field is expected to exist in the packet. This field contains a template string with items to be filled in deliniated within HTML tag style brackets "<EXAMPLE>". The Template Protocol will read the named items from within the packet fill in the CMD_TEMPLATE. This filled in string is then sent out rather than the originally passed in packet.   Correspondingly, if a response is expected the outgoing packet should include a RSP_TEMPLATE and RSP_PACKET field. The RSP_TEMPLATE is used to extract data from the response string and build a corresponding RSP_PACKET. See the TEMPLATE target within the COSMOS Demo configuration for an example of usage.

Check out this [Template Protocol](/news/2017/06/19/template_protocol) blog post for additional tips.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Write Termination Characters | The data to write after writing a command packet. Given as a hex string such as 0xABCD. | Yes |
| Read Termination Characters | The characters which delineate the end of a telemetry packet. Given as a hex string such as 0xABCD. | Yes |
| Ignore Lines | Number of response lines to ignore (completely drop) | No | 0 lines
| Initial Read Delay | An initial delay after connecting after which the interface will be read till empty and data dropped. Useful for discarding connect headers and initial prompts. | No | nil (no initial read)
| Response Lines | The number of lines that make up expected responses | No | 1 line
| Strip Read Termination | Whether to remove the read termination characters before returning the telemetry packet | No | true
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes including the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Fill Fields | Whether or not to fill in the sync pattern on outgoing packets | No | false
| Response Timeout | Number of seconds to wait for a response before timing out | No | 5.0
| Response Polling Period | Number of seconds to wait between polling for a response | No | 0.02
| Raise Exceptions | Whether to raise exceptions when errors occur like timeouts or unexpected responses | No | false
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

## Helper Protocols
COSMOS provides the following helper protocols: Override, and Crc. This protocols provide helper functionality to Interfaces.

### Override Protocol
The Override Protocol allows telemetry items to be overridden when read. This action is permanent and any incoming data is overwritten with the new value. This is in contrast to using the set_tlm() API method which temporarily sets a telemetry value until new data arrives over the interface.

To use this protocol you must add it to your interface wherever that is defined. Typically this is in the target's cmd_tlm_server.txt file but it could also be in the global cmd_tlm_server.txt. For example:

{% highlight bash %}
INTERFACE INST_INT simulated_target_interface.rb sim_inst.rb
  TARGET INST
  PROTOCOL READ OverrideProtocol
{% endhighlight %}

By adding this to your interface you now have access to the following APIs:

{% highlight ruby %}
# Permanently set the converted value of a telemetry point to a given value
override_tlm(target_name, packet_name, item_name, value)
# or
override_tlm("target_name packet_name item_name = value")

# Permanently set the raw value of a telemetry point to a given value
override_tlm_raw(target_name, packet_name, item_name, value)
# or
override_tlm_raw("target_name packet_name item_name = value")

# Clear an override of a telemetry point
normalize_tlm(target_name, packet_name, item_name)
# or
normalize_tlm("target_name packet_name item_name")
{% endhighlight %}

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

### CRC Protocol
The CRC protocol can add CRCs to outgoing commands and verify CRCs on incoming telemetry packets.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Write Item Name | Item to fill with calculated CRC value for outgoing packets (nil = don't fill) | No | nil |
| Strip CRC | Whether or not to remove the CRC from incoming packets | No | false |
| Bad Strategy | How to handle CRC errors on incoming packets.  ERROR = Just log the error, DISCONNECT = Disconnect interface | No | "ERROR" |
| Bit Offset | Bit offset of the CRC in the data. Can be negative to indicate distance from end of packet | No | -32 |
| Bit Size | Bit size of the CRC - Must be 16, 32, or 64 | No | 32 |
| Endianness | Endianness of the CRC (BIG_ENDIAN/LITTLE_ENDIAN) | No | "BIG_ENDIAN" |
| Poly | Polynomial to use when calculating the CRC expressed as an integer | No | nil (use default polynomial - 16-bit=0x1021, 32-bit=0x04C11DB7, 64-bit=0x42F0E1EBA9EA3693) |
| Seed | Seed value to start the calculation | No | nil (use default seed - 16-bit=0xFFFF, 32-bit=0xFFFFFFFF, 64-bit=0xFFFFFFFFFFFFFFFF) |
| Xor | Whether to XOR the CRC result with 0xFFFF | No | nil (use default value - 16-bit=false, 32-bit=true, 64-bit=true) | 
| Reflect | Whether to bit reverse each byte of data before calculating the CRC | No | nil (use default value - 16-bit=false, 32-bit=true, 64-bit=true) |
| Allow Empty Data | Whether or not this protocol will allow an empty string to be passed down to later Protocols (instead of returning :STOP). Can be true, false, or nil, where nil is interpreted as true unless the Protocol is the last Protocol of the chain. (As of COSMOS 4.1.1) | No | nil

## Custom Protocols
Creating a custom protocol is easy and should be the default solution for customizing COSMOS Interfaces (rather than creating a new Interface class).  However, creating custom Interfaces is still useful for defaulting parameters to values that always are fixed for your target, and for including the necessary Protocols. The base COSMOS Interfaces take a lot of parameters that can be confusing to your future users and you may want to create a custom Interface just to set these to hard coded values and cut the available parameters down to something like the hostname and port to connect to.

All custom Protocols should derive from the Protocol class found in the COSMOS gem at [lib/cosmos/interfaces/protocols/protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/protocol.rb).  This class defines the 9 methods that are relevant to writing your own protocol. The base class implementation for each method is included below as well as a discussion as to how the methods should be overridden and used in your own Protocols.

To really understand how Protocols work, you first have to understand the logic within the base Interface class read and write methods. 

Let's first discuss the read method.  

![Interface Read Logic](/img/interface_read_logic.png)

On EVERY call to read, an empty Ruby string "" is first passed down to each of the read Protocol read_data() method BEFORE new raw data is attempted to be read using the Interface's read_interface() method.  This is a signal to Protocols that have cached up more than one packet worth of data to output those cached packets before any new data is read from the Interface.  Typically no data will be cached up and one of the protocols read_data() methods will return :STOP in response to the empty string, indicating that more data is required to generate a packet. Each Protocol's read_data() method can return one of three things: data that will be passed down to any addition Protocols or turned into a Packet, :STOP which means more data is required from the Interface for the Protocol to continue, or :DISCONNECT which means that something has happened that requires disconnecting the Interface (and by default trying to reconnect).  Each protocol's read_data method takes as a single parameter holding the current state of data that will be turned into a packet, and returns a possibly modified set of data.  If the data passes through all Protocol read_data() methods it is then converted into a COSMOS packet using the Interface's convert_data_to_packet() method.  This packet is then run in a similar fashion through each Read Protocol's read_packet() method.  This method has essentially the same return possiblities except it returns a Packet instead of data, or :STOP, or :DISCONNECT.  If the Packet makes it through all read_packet() methods then the Interface packet read counter is incremented ans the Packet is returned to the Interface.

![Interface Write Logic](/img/interface_write_logic.png)

The Interface write() method works very similarily to read.  (It should be mentioned that by default write protocols run in the reverse order of read protocols.  This makes sense if you think about it because when reading you would be stripping of layers of data and when writing you are typically adding on layers in reverse order.) 

First, the packet write counter is incremented.  Then each write Protocol is given a chance to modify the packet by it's write_packet() method being called.  This method can either return a potentially modified packet, :STOP, or :DISCONNECT.  If a write Protocol returns :STOP no data will be written out the Interface and it is assumed that more packets are necessary before a final packet can be output.  :DISCONNECT will disconnect the Interface.  If the packet makes it through all the write Protocols write_packet() methods, then it is converted to binary data using the Interface's convert_packet_to_data() method.  Next the write_data() method is called for each write Protocol giving it a chance to modify the lower level data.  The same return options are available except a Ruby string of data is returned instead of a COSMOS packet.  If the data, makes it through all write_data() methods then it is written out on the Interface using the write_interface() method.  Afterwards, each Protocol's post_write_interface() method is called with both the final modified Packet, and the actual data written out to the Interface.  This method allows followup such as waiting for a response after writing out a message.

## Method discussions

### initialize

This is the constructor for your custom Protocol.  It should always call super(allow_empty_data) to initialize the base Protocol class.  

Base class implementation:

{% highlight ruby %}
    # @param allow_empty_data [true/false] Whether STOP should be returned on empty data
    def initialize(allow_empty_data = false)
      @interface = nil
      @allow_empty_data = ConfigParser.handle_true_false(allow_empty_data)
      reset()
    end
{% endhighlight %}

As you can see, every Protocol maintains state on at least two items.  @interface holds the Interface class instance that the protocol is associated with.  This is sometimes necessary to introspect details that only the Interface knows.   @allow_empty_data is a flag used by the read_data(data) method that is discussed later in this document.

### reset

The reset method is used to reset internal protocol state when the Interface is connected and/or disconnected.  This method should be used for common reseting logic. Connect and Disconnect specific logic are handled in the next two methods.

Base class implementation:

{% highlight ruby %}
    def reset
    end
{% endhighlight %}

As you can see, the base class reset implementation doesn't currently do anything.

### connect_reset

The connect_reset method is used to reset internal Protocol state each time the Interface is connected.

Base class implementation:

{% highlight ruby %}
    def connect_reset
      reset()
    end
{% endhighlight %}

The base class connect_reset implementation just calls the reset method to ensure common reset logic is run.


### disconnect_reset

The disconnect_reset method is used to reset internal Protocol state each time the Interface is disconnected.

Base class implementation:

{% highlight ruby %}
    def disconnect_reset
      reset()
    end
{% endhighlight %}

The base class disconnect_reset implementation just calls the reset method to ensure common reset logic is run.

### read_data

The read_data method is used to analyze and potentially modify any raw data read by an Interface. It takes one parameter as the current state of the data to be analyzed. It can return either a Ruby string of data, :STOP, or :DISCONNECT.  If it returns a Ruby string, then it believes that data may be ready to be a full packet, and is ready for processing by any following Protocols. If :STOP is returned then the Protocol believes it needs more data to complete a full packet. If :DISCONNECT is returned then the Protocol believes the Interface should be disconnected (and typically automatically reconnected).

Base Class Implemenation:

{% highlight ruby %}
    def read_data(data)
      if (data.length <= 0)
        if @allow_empty_data.nil?
          if @interface and @interface.read_protocols[-1] == self
            # Last read interface in chain with auto @allow_empty_data
            return :STOP
          end
        elsif !@allow_empty_data
          # Don't @allow_empty_data means STOP
          return :STOP
        end
      end
      data
    end
{% endhighlight %}

The base class implementation does nothing except return the data it was given.  The only exception to this is when handling an empty string. If the allow_empty_data flag is false or if it nil and the Protocol is the last in the chain, then the base implementation will return :STOP data to indicate that it is time to call the Interface read_interface() method to get more data. Blank strings are used to signal Protocols that they have an opportunity to return a cached packet.

### read_packet

The read_packet method is used to analyze and potentially modify a COSMOS packet before it is returned by the Interface. It takes one parameter as the current state of the packet to be analyzed. It can return either a COSMOS packet, :STOP, or :DISCONNECT.  If it returns a COSMOS packet, then it believes that the packet is valid, should be returned, and is ready for processing by any following Protocols. If :STOP is returned then the Protocol believes the packet should be silently dropped. If :DISCONNECT is returned then the Protocol believes the Interface should be disconnected (and typically automatically reconnected).

Base Class Implementation: 

{% highlight ruby %}
    def read_packet(packet)
      return packet
    end
{% endhighlight %}

The base class always just returns the packet given.

### write_packet

The write_packet method is used to analyze and potentially modify a COSMOS packet before it is output by the Interface. It takes one parameter as the current state of the packet to be analyzed. It can return either a COSMOS packet, :STOP, or :DISCONNECT.  If it returns a COSMOS packet, then it believes that the packet is valid, should be written out the Interface, and is ready for processing by any following Protocols. If :STOP is returned then the Protocol believes the packet should be silently dropped. If :DISCONNECT is returned then the Protocol believes the Interface should be disconnected (and typically automatically reconnected).

Base Class Implementation: 

{% highlight ruby %}
    def write_packet(packet)
      return packet
    end
{% endhighlight %}

The base class always just returns the packet given.

### write_data

The write_data method is used to analyze and potentially modify data before it is written out by the Interface. It takes one parameter as the current state of the data to be analyzed and sent. It can return either a Ruby String of data, :STOP, or :DISCONNECT.  If it returns a Ruby string of data, then it believes that the data is valid, should be written out the Interface, and is ready for processing by any following Protocols. If :STOP is returned then the Protocol believes the data should be silently dropped. If :DISCONNECT is returned then the Protocol believes the Interface should be disconnected (and typically automatically reconnected).

Base Class Implementation: 

{% highlight ruby %}
    def write_data(data)
      return data
    end
{% endhighlight %}

The base class always just returns the data given.

### post_write_interface

The post_write_interface method is called after data has been written out the Interface.  The typical use of this method is to provide a hook to implement command/response type interfaces where a response is always immediately expected in response to a command. It takes two parameters, the packet after all modifications by write_packet() and the data that was actually written out the Interface. It can return either the same pair of packet/data, :STOP, or :DISCONNECT.  If it returns a packet/data pair then they are passed on to any other Protocols. If :STOP is returned then the Interface write() call completes and no further Protocols post_write_interface() methods are called. If :DISCONNECT is returned then the Protocol believes the Interface should be disconnected (and typically automatically reconnected).  Note that only the first parameter "packet", is checked to be :STOP, or :DISCONNECT on the return.

Base Class Implementation: 

{% highlight ruby %}
    def post_write_interface(packet, data)
      return packet, data
    end
{% endhighlight %}

The base class always just returns the packet/data given.

## Examples

Please see the included COSMOS protocol code for examples of the above methods in action.

[lib/cosmos/interfaces/protocols/protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/protocol.rb)
[lib/cosmos/interfaces/protocols/burst_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/burst_protocol.rb)
[lib/cosmos/interfaces/protocols/fixed_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/fixed_protocol.rb)
[lib/cosmos/interfaces/protocols/length_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/length_protocol.rb)
[lib/cosmos/interfaces/protocols/preidentified_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/preidentified_protocol.rb)
[lib/cosmos/interfaces/protocols/terminated_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/terminated_protocol.rb)
[lib/cosmos/interfaces/protocols/template_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/template_protocol.rb)
[lib/cosmos/interfaces/protocols/override_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/override_protocol.rb)
[lib/cosmos/interfaces/protocols/crc_protocol.rb](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/crc_protocol.rb)