---
layout: news_item
title: "Derived Items"
date: 2018-03-14 08:00:00 -0700
author: jmthomas
categories: [post]
---

## COSMOS Derived Items

COSMOS has a concept of a derived item which is a telemetry item that doesn't actually exist in the binary data. Derived items are typically computed based on other telemetry items. COSMOS automatically defines three derived items on every packet: RECEIVED_TIMESECONDS, RECEIVED_TIMEFORMATTED, and RECEIVED_COUNT. The time items are set to the time that the COSMOS Command and Telemetry Server receives the packet. The count is a running count of the number of packets received since the Server started. Note that the count is always a relative count and should only be used accordingly.

COSMOS derived items are defined very similarly to real items except they use the special DERIVED telemetry type. Here is how the default COSMOS derived items might look in a telemetry definition.

```
ITEM PACKET_TIMESECONDS 0 0 DERIVED "COSMOS Received Time (UTC, Floating point, Unix epoch)"
  READ_CONVERSION packet_time_seconds_conversion.rb
  FORMAT_STRING '%0.6f'
ITEM PACKET_TIMEFORMATTED 0 0 DERIVED "COSMOS Received Time (Local time zone, Formatted string)"
  READ_CONVERSION packet_time_formatted_conversion.rb
ITEM RECEIVED_TIMESECONDS 0 0 DERIVED "COSMOS Received Time (UTC, Floating point, Unix epoch)"
  READ_CONVERSION received_time_seconds_conversion.rb
  FORMAT_STRING '%0.6f'
ITEM RECEIVED_TIMEFORMATTED 0 0 DERIVED "COSMOS Received Time (Local time zone, Formatted string)"
  READ_CONVERSION received_time_formatted_conversion.rb
ITEM RECEIVED_COUNT 0 0 DERIVED "COSMOS packet received count"
  READ_CONVERSION received_count_conversion.rb
```

Note the DERIVED type where real items are INT, UINT, FLOAT, STRING or BLOCK. Also note that the bit offset and bit size values are zero. This is due to the fact that these items don't actually exist in the binary packet but are created on the fly when the packet is processed. This also has implications with playback of the data. Since these items don't actually exist in the binary file, they are created on the fly even when doing playback through the Replay tool. Thus if your DERIVED item is aggregating multiple values such as a running average, it will take a few samples to generate a good value.

### Creating a Derived Average

A common usecase is to create a derived item which averages other telemetry points. Let's explore how to do this within the COSMOS Demo. The COSMOS Demo already declares 4 fake temperatures named TEMP1, TEMP2, TEMP3, and TEMP4. Let's create a new derived item called TEMP_AVERAGE that averages them.

```
ITEM TEMP_AVERAGE 0 0 DERIVED "Average of TEMP1, TEMP2, TEMP3, TEMP4"
  GENERIC_READ_CONVERSION_START FLOAT 32
    (packet.read("TEMP1") + packet.read("TEMP2") + packet.read("TEMP3") + packet.read("TEMP4")) / 4.0
  GENERIC_READ_CONVERSION_END
```

The GENERIC_READ_CONVERSION_START keyword also takes two additional argument which describe the output of the conversion. Here we specify FLOAT 32 to indicate the conversion will return a 32 bit floating point value.

In the code section, note the use of the built in variable called 'packet'. When you create a generic conversion you always have access to the 'packet' variable which references the packet the conversion is declared in. For more information about how to use 'packet' please see the [Packet](/docs/v4/packet-class/) documentation. You also have access to 'value' which is the raw value of the current item. In the case of a DERIVED item the value is nil. You can also access 'buffer' which is the raw buffer associated with the packet.

### Using a Conversion Class

While it is easy to create a simple conversion using GENERIC_READ_CONVERSION there are multiple reasons to prefer a Conversion class. Creating a separate conversion class is easier to test, easier to reuse and has better performance. Let's create a conversion which performs averging and rewrite the previous example. First the telemetry definition will now look like this.

```
ITEM TEMP_AVERAGE 0 0 DERIVED "Average of TEMP1, TEMP2, TEMP3, TEMP4"
  READ_CONVERSION average_conversion.rb TEMP1 TEMP2 TEMP3 TEMP4
```

We now need to implement average_conversion.rb to take our arguments and generate the average. Put this new file in the target's lib folder (in the demo this is config/targets/INST/lib).

{% highlight ruby %}
require 'cosmos/conversions/conversion'
module Cosmos
class AverageConversion < Conversion
def initialize(\*args)
super()
@items = args
@converted_type = :FLOAT
@converted_bit_size = 32
end

    def call(value, packet, buffer)
      total = 0
      @items.each do |item|
        total += packet.read(item)
      end
      return total / @items.length
    end

end
end
{% endhighlight %}

Here I'm using the Ruby splat operator to collect all the arguments passed into initialize and assign them to @items. I also explicitly set the @converted_type and @converted_bit_size variables (part of the Conversion base class) to :FLOAT and 32 to indicate our conversion will return a 32 bit floating point number. The call method is what actually performs the conversion. Note how it defines the same three variables I previously talked about: value, packet and buffer. I use the packet argument to read the items passed in and then divide by the total to average them.

We're not yet done though as we need to edit the INST/target.txt file to require this new conversion.

```
REQUIRE average_conversion.rb
```

Running this in the Demo with Telemetry Grapher shows our new average value pretty clearly.

![Tlm Grapher Derived](/img/2018_03_14_tlm_grapher_derived.png)

Conversions and DERIVED variables are powerful ways to add additional telemetry points based on existing data in your packet structure. Another way to add insight into your telemetry is to add [Packet Processors](/news/2017/05/08/packet_processors/) which I've previously blogged about.

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
