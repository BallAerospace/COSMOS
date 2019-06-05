---
layout: docs
title: Interface Configuration
permalink: /docs/interfaces/
toc: true
---
Interface classes provide the code that COSMOS uses to receive real-time telemetry from targets and to send commands to targets. The interface that a target uses could be anything (TCP/IP, serial, GPIB, Firewire, etc.), therefore it is important that this is a customizable portion of any reusable Command and Telemetry System. Fortunately the most common form of interfaces are over TCP/IP sockets, and COSMOS provides interface solutions for these. This guide will discuss how to use these interface classes, and how to create your own. Note that in most cases you can extend interfaces with [Protocols](/docs/protocols/) rather than implementing a new interface.

<div class="note info">
  Note that Interfaces and Routers are very similar and share the same configuration parameters. Routers are simply Interfaces which route an existing Interface's telemetry data out to the connected target and routes the connected target's commands back to the original Interface's target.
</div>

Interfaces have the following methods that must be implemented:

1. **connect** - Open the socket or port or somehow establish the connection to the target. Note: This method may not block indefinitely. Be sure to call super() in your implementation.
1. **connected?** - Return true or false depending on the connection state. Note: This method should return immediately.
1. **disconnect** - Close the socket or port of somehow disconnect from the target. Note: This method may not block indefinitely. Be sure to call super() in your implementation.
1. **read_interface** - Lowest level read of data on the interface. Note: This method should block until data is available or the interface disconnects. On a clean disconnect it should return nil.
1. **write_interface** - Lowest level write of data on the interface. Note: This method may not block indefinitely.

Interfaces also have the following methods that exist and have default implementations. They can be overridden if necessary but be sure to call super() to allow the default implementation to be executed.
1. **read_interface_base** - This method should always be called from read_interface().  It updates interface specific variables that are displayed by CmdTLmServer including the bytes read count, the most recent raw data read, and it handles raw logging if enabled.
1. **write_interface_base** - This method should always be called from write_interface().  It updates interface specific variables that are displayed by CmdTLmServer including the bytes written count, the most recent raw data written, and it handles raw logging if enabled.
1. **read** - Read the next packet from the interface. COSMOS implements this method to allow the Protocol system to operate on the data and the packet before it is returned.
1. **write** - Send a packet to the interface. COSMOS implements this method to allow the Protocol system to operate on the packet and the data before it is sent.
1. **write_raw** - Send a raw binary string of data to the target. COSMOS implements this method by basically calling write_interface with the raw data.

<div class="note warning">
  <h5>Note on Naming</h5>
  <p>When creating your own interfaces, in most cases they will be subclasses of one of the built-in interfaces described below. It is important to know that both the filename and class name of the interface files must match with correct capitalization or you will receive "class not found" errors when trying to load your new interface. For example, an interface file called labview_interface.rb must contain the class LabviewInterface. If the class was named, LabVIEWInterface, for example, COSMOS would not be able to find the class because of the unexpected capitalization.</p>
</div>


## Provided Interfaces
Cosmos provides the following interfaces for use: TCPIP Client, TCPIP Server, UDP, Serial, Command Telemetry Server, and LINC. The interface to use is defined by the [INTERFACE](/docs/system/#interface) and [ROUTER](/docs/system/#router) keywords.

### TCPIP Client Interface
The TCPIP client interface connects to a TCPIP socket to send commands and receive telemetry. This interface is used for targets which open a socket and wait for a connection. This is the most common type of interface.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Host | Machine name to connect to | Yes |
| Write Port | Port to write commands to (can be the same as read port) | Yes |
| Read Port | Port to read telemetry from (can be the same as write port) | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Protocol Type | See Protocols. | No |
| Protocol Arguments | See Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TEMPLATE 0xA 0xA
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 # no built-in protocol
{% endhighlight %}

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword.

### TCPIP Server Interface
The TCPIP server interface creates a TCPIP server which listens for incoming connections and dynamically creates sockets which communicate with the target. This interface is used for targets which open a socket and try to connect to a server.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Write Port | Port to write commands to (can be the same as read port) | Yes |
| Read Port | Port to read telemetry from (can be the same as write port) | Yes |
| Write Timeout | Number of seconds to wait before aborting the write. Pass 'nil' to block on write. | Yes |
| Read Timeout | Number of seconds to wait before aborting the read. Pass 'nil' to block on read. | Yes |
| Protocol Type | See Protocols. | No |
| Protocol Arguments | See Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME tcpip_server_interface.rb 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb 8080 8080 10.0 10.0 TEMPLATE 0xA 0xA
INTERFACE INTERFACE_NAME tcpip_client_interface.rb 8080 8080 10.0 10.0 # no built-in protocol
{% endhighlight %}

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword. Note, TcpipServerInterface processes the [OPTION](/docs/system/#option) modifier.

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

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword.

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
| Protocol Type | See Protocols. | No |
| Protocol Arguments | See Protocols for the arguments each stream protocol takes. | No |

cmd_tlm_server.txt Examples:
{% highlight bash %}
INTERFACE INTERFACE_NAME serial_interface.rb COM1 COM1 9600 NONE 1 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS1 /dev/ttyS1 38400 ODD 1 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME serial_interface.rb COM2 COM2 19200 EVEN 1 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME serial_interface.rb /dev/ttyS0 /dev/ttyS0 57600 NONE 1 10.0 nil PREIDENTIFIED 0xCAFEBABE
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 TEMPLATE 0xA 0xA
INTERFACE INTERFACE_NAME serial_interface.rb COM4 COM4 115200 NONE 1 10.0 10.0 # no built-in protocol
{% endhighlight %}

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword. Note, SerialInterface processes the [OPTION](/docs/system/#option) modifier.

### CmdTlmServer Interface
The CmdTlmServer interface provides a connection to the COSMOS Command and Telemetry Server. This allows scripts and other COSMOS tools to send commands to the CmdTlmServer to enable and disable logging. It also allows scripts and other tools to receive a COSMOS version information packet and a limits change packet which is sent when any telemetry items change limits states. The CmdTlmServer interface can be used by any COSMOS configuration.

cmd_tlm_server.txt Example:
{% highlight bash %}
INTERFACE COSMOSINT cmd_tlm_server_interface.rb
{% endhighlight %}

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword.

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

See [INTERFACE](/docs/system/#interface) for a description of the INTERFACE keyword. See [Interface Modifiers](/docs/system/#interface-modifiers) for a description of the keywords which can follow the INTERFACE keyword.

## Streams
Streams are low level classes that implement read, read_nonblock, write, connect, connected? and disconnect methods. The build-in Stream classes are SerialStream, TcpipSocketStream and TcpipClientStream and they are automatically used when creating a Serial Interface, TCP/IP Server Interface, or TCP/IP Client Interface.

## Protocols
Protocols define the behaviour of an Interface, including differentiating packet boundaries and modifying data as necessary. COSMOS defines the following built-in protocols which can be used with the above interfaces:

| Name | Description |
|------|-------------|
| [Burst](/docs/protocols/#burst-protocol) | Reads as much data as possible from the interface |
| [Fixed](/docs/protocols/#fixed-protocol) | Processes fixed length packets with a known ID position |
| [Length](/docs/protocols/#length-protocol) | Processes a length field at a fixed location and then reads the remainder of the data |
| [Terminated](/docs/protocols/#terminated-protocol) | Delineates packets uses termination characters at the end of each packet |
| [Template](/docs/protocols/#template-protocol) | Processes text based command / response data such as SCPI interfaces |
| [Preidentified](/docs/protocols/#preidentified-protocol) | Internal COSMOS protocol used by COSMOS tools |

These protocols are declared directly after the interface:

{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil FIXED 6 0 nil true
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TERMINATED 0x0D0A 0x0D0A true 0 0xF005BA11
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 10.0 TEMPLATE 0xA 0xA
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil PREIDENTIFIED 0xCAFEBABE
{% endhighlight %}

COSMOS also defines the following helper protocols:

| Name | Description |
|------|-------------|
| [Override](/docs/protocols/#override-protocol) | Allows telemetry items to be fixed to given value when read |
| [CRC](/docs/protocols/#crc-protocol) | Adds CRCs to outgoing packets and verifies CRCs on incoming packets |
| [Ignore](/docs/protocols/#ignore-protocol) | Ignores the specified packet by dropping it |

These protocols are declared after the INTERFACE:

{% highlight bash %}
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF
  TARGET TGT
  PROTOCOL READ OverrideProtocol
  PROTOCOL WRITE CrcProtocol CRC # See the documentation for parameters
{% endhighlight %}

Note the first parameter after the PROTOCOL keyword is how to apply the protocol: READ, WRITE, or READ_WRITE. Read applies the protocol on incoming packets (telemetry) and write on outgoing packets (commands). The next parameter is the protocol filename or class name. All other parameters are protocol specific.

In addition, you can define your own protocols which are declared like the COSMOS helper protocols after your interface. See the <a href="/docs/protocols#custom-protocols">Custom Protocols</a> documentation for more information.
