---
layout: news_item
title: 'Protocols'
date: 2019-06-05 08:00:00 -0700
author: jmthomas
categories: [post]
---
## Protocols
Protocols were introduced into COSMOS in version 4.0.0. Protocols consist of the code that make sense of the incoming byte stream before it is turned into packets. They work hand in hand with the COSMOS interface that connects to the target, whether it is TCP/IP, UDP, or serial. The new COSMOS protocol system makes it possible to add and layer protocols into a COSMOS interface.

### Built-in Protocols
COSMOS comes with a number of built-in protocols that are used directly with the COSMOS provided interfaces. In fact, when you declare your interface you're required to specify a protocol. For example, the following code declares a TCP/IP client with a LENGTH protocol.

```
INTERFACE INTERFACE_NAME tcpip_client_interface.rb localhost 8080 8081 10.0 nil LENGTH 0 16 0 1 BIG_ENDIAN 4 0xBA5EBA11
```

The built-in protocols are fully described on the [Protocols](/docs/protocols) page and also mentioned on the [Interfaces](/docs/interfaces/#protocols) page.

### Custom Protocols
The built-in protocols are enough to support almost all of the data streams that you'll encounter from a target. However, sometimes you need to massage the data a little by stripping off data or adding headers. This is when you should create a custom protocol. Custom protocols have 4 methods they can override to modify the incoming telemetry data or outgoing command data. They are read_data(data), write_data(data) and read_packet(packet) write_packet(packet). The 'data' methods operate on the raw binary data and are used when adding or removing raw bytes from the stream. The 'packet' methods operate on the data after it has been identified and converted to a COSMOS [Packet](/docs/packet_class/).


#### Removing Data
A recent program was interfacing to a particular device that was sending the ASCII ETX character (0x03) at the end of the data. This character wasn't needed and was confusing a legacy application that was parsing the raw data. A custom protocol was created to simply strip off this byte from the data stream.

In the target's lib directory the strip_etx_protocol.rb file was created. Since the protocol had to simply strip off a single byte, it overrides the read_data(data) method.

```
require 'cosmos/interfaces/protocols/protocol'
class StripEtxProtocol < Protocol
  def read_data(data)
    if data[-1] == "\x03"
      return super(data[0..-2])
    else
      return super(data)
    end
  end
end
```

Ruby can index from the back of the array with -1, -2, etc. Thus if the last byte (-1) is a binary 0x03, the protocol returns the data from 0 up to and including the second to last byte (-2). This was added to the interface by declaring it as a READ protocol since it is only modifying the incoming telemetry data.

```
INTERFACE DEV_INT <interface params>
  PROTOCOL READ StripEtxProtocol
```

#### Adding Data
If you need to add framing data or other bits of protocol to your outgoing data you can create a custom protocol.

In the target's lib directory create a file called framing_protocol.rb. Since the protocol is adding data to the outgoing stream, we override the write_data(data) method.

```
require 'cosmos/interfaces/protocols/protocol'
class FramingProtocol < Protocol
  HEADER = "\xDE\xAD\xBE\xEF" # Binary header data
  def write_data(data)
    super(HEADER + data)
  end
end
```

If you have a question, find a bug, or want a feature please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
