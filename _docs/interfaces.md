---
layout: docs
title: Interface Configuration
permalink: /docs/interfaces/
toc: true
---
Interface classes provide the code that COSMOS uses to receive real-time telemetry from targets and to send commands to targets. The interface that a target uses could be anything (TCP/IP, serial, GPIB, Firewire, etc.), therefore it is important that this is a customizable portion of any reusable Command and Telemetry System. Fortunately the most common form of interfaces are over TCP/IP sockets, and COSMOS provides interface solutions for these. This guide will discuss how to use these interface classes, and how to create your own.

Interfaces have the following methods that must be implemented:

1. **connect** - Open the socket or port or somehow establish the connection to the target.  Note: This method may not block indefinitely.
1. **connected?** - Return true or false depending on the connection state. Note: This method should return immediately
1. **disconnect** - Close the socket or port of somehow disconnect from the target.  Note: This method may not block indefinitely.
1. **read_interface** - Lowest level read of data on the interface. Note: This method should block until data is available or the interface disconnects.  On a clean disconnect it should return nil.
1. **write_interface** - Lowest level write of data on the interface. Note: This method may not block indefinitely.
1. **write_raw** - Send a raw binary string of data to the target. Note: This method may not block indefinitely.

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
| Stream Protocol Type | See Streams and Stream Protocols. | No |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TEMPLATE 0xA 0xA
{% endhighlight %}

### TCPIP Server Interface
The TCPIP server interface creates a TCPIP server which listens for incoming connections and dynamically creates sockets which communicate with the target. This interface is used for targets which open a socket and try to connect to a server.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Port | Port to write commands to (can be the same as read port) | Yes |
| Read Port | Port to read telemetry from (can be the same as write port) | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Stream Protocol Type | See Streams and Stream Protocols. | No |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb 8080 8080 10.0 10.0 TEMPLATE 0xA 0xA
{% endhighlight %}

### UDP Interface
The UDP interface uses UDP packets to send and receive telemetry from the target.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Host | Host name or IP address of the machine to send and receive data with | Yes |
| Write Dest Port | Port on the remote machine to send commands to | Yes |
| Read Port | Port on the remote machine to read telemetry from | Yes |
| Write Source Port | Port on the local machine to send commands from | No | nil (socket is not bound to an outgoing port)
| Interface Address | If the remote machine supports multicast the interface address is used to configure the outgoing multicast address | No | nil (not used)
| TTL | Time to Live. The number of intermediate routers allowed before dropping the packet. | No | 128 (Windows)
| Write Timeout | Number of seconds to wait before aborting the write | No | nil (block on write)
| Read Timeout | Number of seconds to wait before aborting the read | No | nil (block on read)

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
| Stream Protocol Type | See Streams and Stream Protocols. | No |
| Stream Protocol Arguments | See Streams and Stream Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME serial_interface.rb COM1 COM1 9600 NONE 1 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS1 /dev/ttyS1 38400 ODD 1 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME serial_interface.rb COM2 COM2 19200 EVEN 1 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS0 /dev/ttyS0 57600 NONE 1 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 TEMPLATE 0xA 0xA
{% endhighlight %}

### CmdTlmServer Interface
The CmdTlmServer interface provides a connection to the COSMOS Command and Telemetry Server. This allows scripts and other COSMOS tools to send commands to the CmdTlmServer to enable and disable logging. It also allows scripts and other tools to receive a COSMOS version information packet and a limits change packet which is sent when any telemetry items change limits states. The CmdTlmServer interface can be used by any COSMOS configuration.

cmd_tlm_server.txt Example:
{% highlight bash %}
INTERFACE COSMOSINT cmd_tlm_server_interface.rb
{% endhighlight %}

### LINC Interface
The LINC interface uses a single TCPIP socket to talk to a Ball Aerospace LINC Labview target.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Host | Machine name to connect to | Yes |
| Port | Port to write commands to and read telemetry from | Yes |
| Handshake Enabled | Enable command handshaking where commands block until the corresponding handshake message is received | No | true
| Response Timeout | Number of seconds to wait for a handshaking response | No | 5 seconds
| Read Timeout | Number of seconds to wait before aborting the read | No | nil (block on read)
| Write Timeout | Number of seconds to wait before aborting the write | No | 5 seconds
| Length Bit Offset | The bit offset of the length field. Every packet using this interface must have the same structure such that the length field is the same size at the same location. | No | 0 bits
| Length Bit Size | The size in bits of the length field | No | 16 bits
| Length Value Offset | The offset to apply to the length field value. For example if the length field indicates packet length minus one, this value should be one. | No | 4
| Fieldname GUID | Fieldname of the GUID field | No | 'HDR_GUID'
| Length Endianness | The endianness of the length field. Must be either 'BIG_ENDIAN' or 'LITTLE_ENDIAN'. | No | 'BIG_ENDIAN'
| Fieldname Cmd Length | Fieldname of the length field | No | 'HDR_LENGTH'

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME linc_interface.rb localhost 8080
INTERFACE INTERFACE_NAME linc_interface.rb localhost 8080 true 5 nil 5 0 16 4 HDR_GUID BIG_ENDIAN HDR_LENGTH
{% endhighlight %}

## Streams
Streams are low level classes that implement read, read_nonblock, write, connect, connected? and disconnect methods. The build-in Stream classes are SerialStream, TcpipSocketStream and TcpipClientStream and they are automatically used when creating a Serial Interface, TCP/IP Server Interface, or TCP/IP Client Interface.

## Protocols
Protocols process data on behalf of an interface. They can modify the data being written, data being read, or both. Protocols can be layered and will be processed in order. For example, if you have a low level encryption layer that must be first removed before processing a higher level buffer length protocol. COSMOS provides the following protocols: Burst, Fixed, Length, Override, Preidentified, Template, and Terminated.

### Burst Protocol
The Burst Protocol simply reads as much data as it can from the interface before returning the data as a COSMOS Packet. This Protocol relies on regular bursts of data delimited by time and thus is not very robust. However it can utilize a sync pattern which does allow it to re-sync if necessary. It can also discard bytes from the incoming data to remove the sync pattern. Finally it can add sync patterns to data being written out of the interface.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned | No | nil (no sync pattern)
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets | No | false

### Fixed Protocol
The Fixed Protocol reads a preset minimum amount of data which is necessary to properly identify all the defined packets using the interface. It then identifies the packet and proceeds to read as much data from the interface as necessary to create the packet which it then returns. This protocol relies on all the packets on the interface being fixed in length. For example, all the packets using the interface are a fixed size and contain a simple header with a 32 bit sync pattern followed by a 16 bit ID. The Fixed Protocol would elegantly handle this case with a minimum read size of 6 bytes. The Fixed Protocol also supports a sync pattern, discarding leading bytes, and filling the sync pattern similar to the Burst Protocol.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Minimum ID Size | The minimum amount of bytes needed to identify a packet. All the packet definitions must declare their ID_ITEM(s) within this given amount of bytes. | Yes |
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes starting with the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Telemetry | Whether the data is telemetry | No | true (false means command)
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets | No | false

### Length Protocol
The Length Protocol depends on a length field at a fixed location in the defined packets using the interface. It then reads enough data to grab the length field, decodes it, and reads the remaining length of the packet. For example, all the packets using the interface contain a CCSDS header with a length field. The Length Protocol can be set up to handle the length field and even the "length - 1" offset the CCSDS header uses. The Length Protocol also supports a sync pattern, discarding leading bytes, and filling the length and sync pattern similar to the Burst Protocol.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Length Bit Offset | The bit offset of the length field. Every packet using this interface must have the same structure such that the length field is the same size at the same location. Be sure to account for the length of the Sync Pattern in this value (if present). | No | 0 bits
| Length Bit Size | The size in bits of the length field | No | 16 bits
| Length Value Offset | The offset to apply to the length field value. For example if the length field indicates packet length minus one, this value should be one. Be sure to account for the length of the Sync Pattern in this value (if present). | No | 0
| Bytes per Count | The number of bytes per each length field 'count'. This is used if the units of the length field is something other than bytes, for example if the length field count is in words. | No | 1 byte
| Length Endianness | The endianness of the length field. Must be either 'BIG_ENDIAN' or 'LITTLE_ENDIAN'. | No | 'BIG_ENDIAN'
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes including the sync pattern if the sync pattern is being used. Discarding is one of the very last steps so any size and offsets above need to account for all the data before discarding. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Max Length | The maximum allowed value in the length field | No | nil (no maximum length)
| Fill Length and Sync Pattern | Setting this flag to true causes the length field and sync pattern (if present) to be filled automatically on outgoing packets. | No | false

### Terminated Protocol
The Terminated Protocol delineates packets using termination characters found at the end of every packet. It continuously reads data until the termination characters are found at which point it returns the packet data. For example, all the packets using the interface are followed by 0xABCD. This data can either be a part of each packet that is kept or something which is known only by the Terminated Protocol and simply thrown away.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Write Termination Characters | The data to write after writing a command packet. Given as a hex string such as 0xABCD. | Yes |
| Read Termination Characters | The characters which delineate the end of a telemetry packet. Given as a hex string such as 0xABCD. | Yes |
| Strip Read Termination | Whether to remove the read termination characters before returning the telemetry packet | No | true
| Discard Leading Bytes | The number of bytes to discard from the binary data after reading. Note that this applies to bytes including the sync pattern if the sync pattern is being used. | No | 0 (do not discard bytes)
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found including the sync pattern will be returned. | No | nil (no sync pattern)
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets | No | false

### Preidentified Protocol
The Preidentified Protocol is used internally by the COSMOS Command and Telemetry Server only and delineates packets using a custom COSMOS header. This Protocol is configured by default on port 7779 and is created by the Command and Telemetry Server to allow tools to connect and receive the entire packet stream. The Telemetry Grapher uses this port to receive all the packets following through the Command and Telemetry Server in case any need to be graphed.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| Sync Pattern | Hex string representing a byte pattern that will be searched for in the raw data. This pattern represents a packet delimiter and all data found AFTER the sync pattern will be returned. The sync pattern itself is discarded. | No | nil (no sync pattern)
| Max Length | The maximum allowed value in the length field | No | nil (no maximum length)

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
| Fill Sync Pattern | Whether or not to fill in the sync pattern on outgoing packets | No | false
