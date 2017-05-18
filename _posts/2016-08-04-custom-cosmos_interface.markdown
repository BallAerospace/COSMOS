---
layout: news_item
title: 'Custom COSMOS Interface'
date: 2016-08-04 00:00:00 -0700
author: jmthomas 
categories: [post]
---

One of our Ball Aerospace engineers asked how they could add a checksum to an existing COSMOS interface when talking to their target. COSMOS does not support this directly so it requires creating a custom interface. While this might sound daunting, the COSMOS interfaces were designed just for this type of extension and provide hooks for customization.

In this example we will assume the original interface is the COSMOS [Serial Interface](http://cosmosrb.com/docs/interfaces/#serial-interface). In your target's lib folder create a new interface called checksum_serial_interface.rb:

{% highlight ruby %}
require 'cosmos' # always require cosmos
require 'cosmos/interfaces/serial_interface' # original interface being extended

module Cosmos
class ChecksumSerialInterface < SerialInterface
  def pre_write_packet(packet)
    data = packet.buffer
    checksum = 0xFFFF
    data.each_byte {|x| checksum += x }
    checksum &= 0xFFFF
    data << [checksum].pack("n") # Pack as 16 bit unsigned bit endian
    return data
  end

  def post_read_data(packet_data)
    len = packet_data.length
    calc_checksum = 0xFFFF
    packet_data[0..(len - 3)].each_byte {|x| calc_checksum += x }
    calc_checksum &= 0xFFFF
    rx_checksum = packet_data[-2..-1].unpack("n") # Unpack as 16 bit unsigned big endian
    if calc_checksum == rx_checksum
      return packet_data
    else
      puts "Bad checksum detected. Calculated: 0x#{calc_checksum.to_s(16)} Received: 0x#{rx_checksum.to_s(16)}. Dropping packet."
      return "" # Also can return nil to break the connection and reconnect to the target
    end
  end

end
end
{% endhighlight %}

What we're doing is overriding pre_write_packet in StreamInterface to allow us to modify the data before it is written to the packet and sent over the interface. We also override post_read_data to operate on data received before it is sent back to the COSMOS server and thus the tools. Note there is also a post_read_packet(packet) method which is called after post_read_data is called and after the COSMOS Packet has been created. All Interfaces inheriting from StreamInterface includes these callback methods, including SerialInterface, TcpipServerInterface, and TcpipClientInterface. Note that UdpInterface inherits directly from Interface and thus does NOT include these callbacks.

Then in your cmd_tlm_server.txt file for your target you use your new interface:
```
#         interface name  file name                    write read baud   parity stop timeouts stream
INTERFACE UART_INTERFACE  checksum_serial_interface.rb COM1  COM1 115200 NONE   1    nil nil  BURST
```

I added a comment line above the definition which describes the settings. For more information see the [Serial Interface](http://cosmosrb.com/docs/interfaces/#serial-interface) documentation.

This same technique can obviously be used to extend the the other TCPIP interfaces and can be used with all the various [Stream Protocol](http://cosmosrb.com/docs/interfaces/#streams-and-stream-protocols) classes COSMOS defines.
