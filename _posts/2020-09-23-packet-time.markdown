---
layout: news_item
title: "Packet Time"
date: 2020-09-23 08:00:00 -0700
author: jmthomas
categories: [post]
---

It's been said that there are only [two hard things](https://martinfowler.com/bliki/TwoHardThings.html) in programming. I think a corollary to that is [time is hard](https://medium.com/@BlueTaslem/time-is-hard-for-computers-programmers-14ef2a7ece77). So I wanted to write a post about some of the various things COSMOS does with time and what you need to be aware of.

### Received Time

If you've used COSMOS for a while you've noticed that COSMOS automatically creates several telemetry items on every packet: PACKET_TIMESECONDS, PACKET_TIMEFORMATTED, RECEIVED_COUNT, RECEIVED_TIMEFORMATTED, and RECEIVED_TIMESECONDS. While RECEIVED_COUNT is fairly self-explanatory (number of times the packet has been received) it might not be obvious why there are 4! ways to get the time.

So what's the difference between RECEIVED_TIME vs PACKET_TIME. First of all they both have a TIMEFORMATTED and TIMESECONDS version. The formatted telemetry item returns the date and time in a YYYY/MM/DD HH:MM:SS.sss format in the local timezone. This is useful for human readable output like in [Telemetry Extractor](/docs/tools/#telemetry-extractor). They also can return TIMESECONDS which is the floating point UTC time in seconds from the Unix epoch.

RECEIVED_TIME is the time that COSMOS receives the packet. This is set by the interface which is connected to the target and is receiving the raw data. Once a packet has been created out of the raw data the time is set.

PACKET_TIME is a recent ([4.3.0](https://cosmosrb.com/news/2018/08/30/cosmos-4-3-0-released/)) concept introduced by a [change to support stored telemetry](https://github.com/BallAerospace/COSMOS/issues/814). The [Packet](/docs/packet_class/) class has a new method called [packet_time](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/packet.rb#L243) that by default simply returns the received time as set by COSMOS. But if you define a telemetry item called 'PACKET_TIME', that item will be used instead.

This was done to support processing 'stored' telemetry data which isn't coming into COSMOS in real-time. Previously if you created an interface to process stored telemetry, COSMOS would set the received_time as fast as it processed the files and all your stored telemetry would effective have a timestamp of 'now'. This would have also updated the current value table in COSMOS which affect scripts, screens, etc. With COSMOS 4.3.0 and later you can set the 'stored' flag in your interface and the current value table is unaffected. Also if you define a 'PACKET_TIME' item in your packet, this item will be used to calculate the time.

### Example

COSMOS provides a Unix time conversion class which returns a Ruby time object based on the number of seconds and (optionally) microseconds since the Unix epoch. Note: This returns a Ruby Time object and not a float or string!

```
  ITEM PACKET_TIME 0 0 DERIVED "Ruby time based on TIMESEC and TIMEUS"
    READ_CONVERSION unix_time_conversion.rb TIMESEC TIMEUS
```

Definining PACKET_TIME allows the PACKET_TIMESECONDS and PACKET_TIMEFORMATTED to be calculated against an internal Packet time rather than the time that COSMOS receives the packet.

If you have a question, find a bug, or want a feature please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
