---
layout: docs
title: Protocol Configuration
permalink: /docs/protocols/
toc: true
---
Interface classes provide the code that COSMOS uses to receive real-time telemetry from targets and to send commands to targets. Protocols are applied to those interfaces to modify the data as it is received or before it is sent out. Protocols are a new concept in COSMOS 4.0.0 and provide a great deal of flexibility in how interfaces handle data.

## Provided Protocols
Cosmos provides the following protocol: [OverrideProtocol](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/override_protocol.rb). This protocol implements the base class [Protocol](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/interfaces/protocols/protocol.rb) to allow telemetry items to be overridden when read. This action is permanent and any incoming data is overwritten with the new value. This is in contrast to using the set_tlm() API method which temporarily sets a telemetry value until new data arrives over the interface.

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

## Custom Protocols
To create your own custom protocol you'll need to talk to Ryan.
