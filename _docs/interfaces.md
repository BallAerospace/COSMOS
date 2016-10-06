---
layout: docs
title: Interface Configuration
permalink: /docs/interfaces/
---

<div class="toc">
{% capture toc %}{% include interfaces_toc.md %}{% endcapture %}
{{ toc | markdownify }}
</div>

Interface classes provide the code that COSMOS uses to receive real-time telemetry from targets and to send commands to targets. The interface that a target uses could be anything (TCP/IP, serial, GPIB, Firewire, etc.), therefore it is important that this is a customize-able portion of any reusable Command and Telemetry System. Fortunately the most common form of interfaces are over TCP/IP sockets, and COSMOS provides interface solutions for these. This guide will discuss how to use these interface classes, and how to create your own.

Interfaces have the following methods that must be implemented:

1. **connect** - Open the socket or port or somehow establish the connection to the target.  Note: This method may not block indefinitely.
1. **connected?** - Return true or false depending on the connection state. Note: This method should return immediately
1. **disconnect** - Close the socket or port of somehow disconnect from the target.  Note: This method may not block indefinitely.
1. **read** - Return the next packet of data from the target. Note: This method should block until a packet is available or the interface disconnects.  On a clean disconnect it should return nil.
1. **write** - Send a packet of data to the target. Note: This method may not block indefinitely.
1. **write_raw** - Send a raw binary string of data to the target. Note: This method may not block indefinitely.
1. **read_allowed?** - Whether reading from the target over the interface is allowed. Note: This method should return immediately
1. **write_allowed?** - Whether writing a packet to the target over the interface is allowed. Note: This method should return immediately
1. **write_raw_allowed?** - Whether writing raw data to the target over the interface is allowed. Note: This method should return immediately

<div class="note warning">
  <h5>Note on Naming</h5>
  <p>When creating your own interfaces, in most cases they will be subclasses of one of the built-in interfaces described below.   It is important to know that both the filename and class name of the interface files must match with correct capitalization or you will receive "class not found" errors when trying to load your new interface.  For example, an interface file called labview_interface.rb must contain the class LabviewInterface.  If the class was named, LabVIEWInterface, for example, COSMOS would not be able to find the class because of the unexpected capitalization.</p>
</div>



## Provided Interfaces
Cosmos provides the following interfaces for use: TCPIP Client, TCPIP Server, UDP, Serial, Command Telemetry Server, and LINC.

### TCPIP Client Interface
The TCPIP client interface connects to a TCPIP socket to send commands and receive telemetry. This interface is used for targets which open a socket and wait for a connection. This is the most common type of interface.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Host | Machine name to connect to | Yes |
| Write Port | Port to write commands to (can be the same as read port) | Yes |
| Read Port | Port to read telemetry from (can be the same as write port) | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Stream Protocol Type | See Streams and Stream Protocols. | Yes |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | Yes |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
{% endhighlight %}

### TCPIP Server Interface
The TCPIP server interface creates a TCPIP server which listens for incoming connections and dynamically creates sockets which communicate with the target. This interface is used for targets which open a socket and try to connect to a server.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Port | Port to write commands to (can be the same as read port) | Yes |
| Read Port | Port to read telemetry from (can be the same as write port) | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Stream Protocol Type | See Streams and Stream Protocols. | Yes |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | Yes |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
{% endhighlight %}

### UDP Interface
The UDP interface uses UDP packets to send and receive telemetry from the target. It can not use any stream protocols.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Host | Host name or IP address of the machine to send and receive data with | Yes |
| Write Dest Port | Port on the remote machine to send commands to | Yes |
| Read Port | Port on the remote machine to read telemetry from | Yes |
| Write Source Port | Port on the local machine to send commands from. This can be 'nil' in which case the socket will not be bound to a outgoing port. | No |
| Interface Address | If the remote machine supports multicast the interface address is used to configure the outgoing multicast address. This can be 'nil' if unused. | No |
| TTL | Time to Live. The number of intermediate routers allowed before dropping the packet. The default on Windows platforms is 128. | No |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | No |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | No |

cmd_tlm_server.txt Example:
{% highlight bash %}
INTERFACE INTERFACE_NAME udp_interface.rb localhost 8080 8081 8082 nil 128 10.0 nil
{% endhighlight %}

### Serial Interface
The serial interface connects to a target over a serial port. COSMOS provides drivers for both Windows and POSIX drivers for UNIX based systems.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Port | Name of the serial port to write, e.g. 'COM1' or '/dev/ttyS0'. Pass 'nil' to disable writing. | Yes |
| Read Port | Name of the serial port to read, e.g. 'COM1' or '/dev/ttyS0'. Pass 'nil' to disable reading. | Yes |
| Baud Rate | Baud rate to read and write | Yes |
| Parity | Serial port parity. Must be 'NONE', 'EVEN', or 'ODD'. | Yes |
| Stop Bits | Number of stop bits, e.g. 1. | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Stream Protocol Type | See Streams and Stream Protocols. | Yes |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | Yes |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME serial_interface.rb COM1 COM1 9600 NONE 1 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS1 /dev/ttyS1 38400 ODD 1 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME serial_interface.rb COM2 COM2 19200 EVEN 1 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS0 /dev/ttyS0 57600 NONE 1 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
{% endhighlight %}

### CmdTlmServer Interface
The CmdTlmServer interface provides a connection to the COSMOS Command and Telemetry Server. This allows scripts and other COSMOS tools to send commands to the CmdTlmServer to enable and disable logging. It also allows scripts and other tools to receive a COSMOS version information packet and a limits change packet which is sent when any telemetry items change limits states. The CmdTlmServer interface can be used by any COSMOS configuration.

cmd_tlm_server.txt Example:
{% highlight bash %}
INTERFACE COSMOSINT cmd_tlm_server_interface.rb
{% endhighlight %}

### LINC Interface
The LINC interface uses a single TCPIP socket to talk to a Ball Aerospace LINC Labview target.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Host | Machine name to connect to | Yes |
| Port | Port to write commands to and read telemetry from | Yes |
| Handshake Enabled | Enable command handshaking where commands block until the corresponding handshake message is received. The default is true. | No |
| Response Timeout | Number of seconds to wait for a handshaking response. The default is 5 seconds. | No |
| Read Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on read. The default is nil. | No |
| Write Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on write. The default is 5 seconds. | No |
| Length Bit Offset | The bit offset of the length field. Every packet using this interface must have the same structure such that the length field is the same size at the same location. The default is 0. | No |
| Length Bit Size | The size in bits of the length field. The default is 16. | No |
| Length Value Offset | The offset to apply to the length field value. For example if the length field indicates packet length minus one, this value should be one. The default is 4. | No |
| Fieldname GUID | Fieldname of the GUID field. The default is 'HDR_GUID' | No |
| Length Endianness | The endianness of the length field. Must be either 'BIG_ENDIAN' or 'LITTLE_ENDIAN'. The default is 'BIG_ENDIAN'. | No |
| Fieldname Cmd Length | Fieldname of the length field. The default is 'HDR_LENGTH' | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME linc_interface.rb localhost 8080
INTERFACE INTERFACE_NAME linc_client_interface.rb localhost 8080 true 5 nil 5 0 16 4 HDR_GUID BIG_ENDIAN HDR_LENGTH
{% endhighlight %}

## Streams and Stream Protocols
Streams are simplified interfaces that only implement the read, read_nonblock, write, connected? and disconnect methods. They are basically just data sinks and sources which are further manipulated by stream protocols. COSMOS provides the following streams: SerialStream, TcpipClientStream, and TcpipSocketStream. As you might guess, the SerialInterface, TcpipClientInterface, TcpipServerInterface directly use the SerialStream, TcpipClientStream, and TcpipSocketStream respectively. In addition, these interfaces require a StreamProtocol to process the data on the stream.

StreamProtocols process a stream of data on behalf of an interface. Once they are connected to their streams, they will continuously read from the stream to amass a buffer of raw data which is then processed according to the protocol type. COSMOS provides the following stream protocols: Burst, Fixed, Length, Terminated, Preidentified, and Templated.

### Burst Stream Protocol
The Burst Stream Protocol simply reads as much data as it can from the stream before returning the data as a COSMOS Packet. This Protocol relies on regular bursts of data delimited by time and thus is not very robust. However it can utilize a sync pattern which does allow it to re-sync from the stream if necessary.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading from the stream. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. The default is 0 which means to not discard any bytes. | No |
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. The default is 'nil' which means no sync pattern is used. | No |
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets. Defaults to false. | No |

### Fixed Stream Protocol
The Fixed Stream Protocol reads a preset minimum amount of data from the stream which is necessary to properly identify all the defined packets using the interface. It then identifies the packet and proceeds to read as much data from the stream as necessary to create the packet which it then returns. This stream relies on all the packets on the interface being fixed in length. For example, all the packets using the interface are a fixed size and contain a simple header with a 32 bit sync pattern followed by a 16 bit ID. The Fixed Stream Protocol would elegantly handle this case with a minimum read size of 6 bytes.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Minimum ID Size | The minimum amount of bytes needed to identify a packet. All the packet definitions must declare their ID_ITEM(s) within this given amount of bytes. | Yes |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading from the stream. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. The default is 0 which means to not discard any bytes. | No |
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. The default is 'nil' which means no sync pattern is used. | No |
| Telemetry Stream | Whether the stream is returning telemetry. The default is true which means this is a telemetry stream. Pass false to declare a command stream. | No |
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets. Defaults to false. | No |

### Length Stream Protocol
The Length Stream Protocol depends on a length field at a fixed location in the defined packets using the interface. It then reads enough data to grab the length field, decodes it, and reads the remaining length of the packet. For example, all the packets using the interface contain a CCSDS header with a length field. The Length Stream Protocol can be set up to handle the length field and even the "length - 1" offset the CCSDS header uses.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Length Bit Offset | The bit offset of the length field. Every packet using this interface must have the same structure such that the length field is the same size at the same location. The default is 0. Be sure to account for the length of the Sync Pattern in this value (if present). | No |
| Length Bit Size | The size in bits of the length field. The default is 16. | No |
| Length Value Offset | The offset to apply to the length field value. For example if the length field indicates packet length minus one, this value should be one. The default is 0. Be sure to account for the length of the Sync Pattern in this value (if present). | No |
| Bytes per Count | The number of bytes per each length field 'count'. This is used if the units of the length field is something other than bytes, for example if the length field count is in words. The default is 1. | No |
| Length Endianness | The endianness of the length field. Must be either 'BIG_ENDIAN' or 'LITTLE_ENDIAN'. The default is 'BIG_ENDIAN'. | No |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading from the stream. Note that this applies to bytes including the sync pattern if the sync pattern is being used. The default is 0 which means to not discard any bytes.  Discarding is one of the very last steps so any size and offsets above need to account for all the data before discarding.	| No |
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. The default is 'nil' which means no sync pattern is used. | No |
| Max Length | The maximum allowed value in the length field. The default is nil which means there is no maximum length.	| No |
| Fill Length and Sync Pattern | Setting this flag to true causes the length field and sync pattern (if present) to be filled automatically on outgoing packets. Defaults to false. | No |

### Terminated Stream Protocol
The Terminated Stream Protocol delineates packets using termination characters found at the end of every packet. It continuously reads data from the stream until the termination characters are found at which point it returns the packet data. For example, all the packets using the interface are followed by 0xABCD. This data can either be a part of each packet that is kept or something which is known only by the Terminated Stream Protocol and simply thrown away.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Termination Characters | The data to write to the stream after writing a command packet. Given as a hex string such as 0xABCD. The default is the empty string '' which means to write no termination characters. | No |
| Read Termination Characters | The characters at the end of the stream which delineate the end of a telemetry packet. Given as a hex string such as 0xABCD. The default is the empty string '' which won't work. | No |
| Strip Read Termination | Whether to remove the read termination characters from the stream before returning the telemetry packet. The default is true. | No |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading from the stream. Note that this applies to bytes including the sync pattern if the sync pattern is being used. The default is 0 which means to not discard any bytes. | No |
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. The default is 'nil' which means no sync pattern is used. | No |
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets. Defaults to false. | No |

### Preidentified Stream Protocol
The Preidentified Stream Protocol is used internally by the COSMOS Command and Telemetry Server only and delineates packets using a custom COSMOS header. This stream Protocol is configured by default on port 7779 and is created by the Command and Telemetry Server to allow tools to connect and receive the entire packet stream. The Telemetry Grapher uses this port to receive all the packets following through the Command and Telemetry Server in case any need to be graphed.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found AFTER the sync pattern will be returned. The sync pattern itself is discarded. The default is 'nil' which means no sync pattern is used. | No |
| Max Length | The maximum allowed value in the length field. The default is nil which means there is no maximum length.	| No |

### Templated Stream Protocol
The Templated Stream Protocol works much like the Terminated Stream Protocol except it designed for text-based command and response type interfaces.  It delineates packets in the same way as the terminated stream protocol except each packet is referred to as a line (because each usually contains a line of text).  For outgoing packets a CMD_TEMPLATE field is expected to exist in the packet.  This field contains a template string with items to be filled in deliniated within HTML tag style brackets "<EXAMPLE>".  The Templated Stream Protocol will read the named items from within the packet fill in the CMD_TEMPLATE.  This filled in string is then sent out rather than the originally passed in packet.   Correspondingly, if a response is expected the outgoing packet should include a RSP_TEMPLATE and RSP_PACKET field.  The RSP_TEMPLATE is used to extract data from the response string and build a corresponding RSP_PACKET.   See the TEMPLATED target within the COSMOS Demo configuration for an example of usage.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Termination Characters | The data to write to the stream after writing a command packet. Given as a hex string such as 0xABCD. The default is the empty string '' which means to write no termination characters. | No |
| Read Termination Characters | The characters at the end of the stream which delineate the end of a telemetry packet. Given as a hex string such as 0xABCD. The default is the empty string '' which won't work. | No |
| Ignore Lines | Number of response lines to ignore (completely drop). Defaults to 0. | No |
| Initial Read Delay | An initial delay after connecting after which the stream will be read till empty and data dropped. Useful for discarding connect headers and initial prompts. Defaults to nil which means no initial read. | 	No |
| Response Lines | The number of lines that make up expected responses. Defaults to 1. | No |
| Strip Read Termination | Whether to remove the read termination characters from the stream before returning the telemetry packet. The default is true. | No |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading from the stream. Note that this applies to bytes including the sync pattern if the sync pattern is being used. The default is 0 which means to not discard any bytes. | No |
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw stream. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. The default is 'nil' which means no sync pattern is used. | No |
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets. Defaults to false. | No |
