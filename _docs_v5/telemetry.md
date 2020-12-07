---
layout: docs
title: Telemetry Configuration
toc: true
---

## Telemetry Definition Files

Telemetry definition files define the telemetry packets that can be received and processed from COSMOS targets. One large file can be used to define the telemetry packets, or multiple files can be used at the user's discretion. Telemetry definition files are placed in the config/TARGET/cmd_tlm directory and are processed alphabetically. Therefore if you have some telemetry files that depend on others, e.g. they override or extend existing telemetry, they must be named last. The easist way to do this is to add an extension to an existing file name. For example, if you already have tlm.txt you can create tlm_override.txt for telemetry that depends on the definitions in tlm.txt. Note that due to the way the [ASCII Table](http://www.asciitable.com/) is structured, files beginning with capital letters are processed before lower case letters.

When defining telemetry items you can choose from the following data types: INT, UINT, FLOAT, DERIVED, STRING, BLOCK. These correspond to integers, unsigned integers, floating point numbers, derived values of 0 size which aren't actually physically defined in the packet, strings and binary blocks of data. The only difference between a STRING and BLOCK is when COSMOS reads a STRING type it stops reading when it encounters a null byte (0). This shows up when displaying the value in Packet Viewer or Tlm Viewer and in the output of Telemetry Extractor.

<div style="clear:both;"></div>

{% cosmos_meta telemetry.yaml %}

## Example File

**Example File: &lt;COSMOSPATH&gt;/config/TARGET/cmd_tlm/tlm.txt**

{% highlight bash %}
TELEMETRY TARGET HS BIG_ENDIAN "Health and Status for My Target"
ITEM CCSDSVER 0 3 UINT "CCSDS PACKET VERSION NUMBER (SEE CCSDS 133.0-B-1)"
ITEM CCSDSTYPE 3 1 UINT "CCSDS PACKET TYPE (COMMAND OR TELEMETRY)"
STATE TLM 0
STATE CMD 1
ITEM CCSDSSHF 4 1 UINT "CCSDS SECONDARY HEADER FLAG"
STATE FALSE 0
STATE TRUE 1
ID_ITEM CCSDSAPID 5 11 UINT 102 "CCSDS APPLICATION PROCESS ID"
ITEM CCSDSSEQFLAGS 16 2 UINT "CCSDS SEQUENCE FLAGS"
STATE FIRST 0
STATE CONT 1
STATE LAST 2
STATE NOGROUP 3
ITEM CCSDSSEQCNT 18 14 UINT "CCSDS PACKET SEQUENCE COUNT"
ITEM CCSDSLENGTH 32 16 UINT "CCSDS PACKET DATA LENGTH"
ITEM CCSDSDAY 48 16 UINT "DAYS SINCE EPOCH (JANUARY 1ST, 1958, MIDNIGHT)"
ITEM CCSDSMSOD 64 32 UINT "MILLISECONDS OF DAY (0 - 86399999)"
ITEM CCSDSUSOMS 96 16 UINT "MICROSECONDS OF MILLISECOND (0-999)"
ITEM ANGLEDEG 112 16 INT "Instrument Angle in Degrees"
POLY_READ_CONVERSION 0 57.295
ITEM MODE 128 8 UINT "Instrument Mode"
STATE NORMAL 0 GREEN
STATE DIAG 1 YELLOW
MACRO_APPEND_START 1 5
APPEND_ITEM SETTING 16 UINT "SETTING #x"
MACRO_APPEND_END
ITEM TIMESECONDS 0 0 DERIVED "DERIVED TIME SINCE EPOCH IN SECONDS"
GENERIC_READ_CONVERSION_START FLOAT 32
((packet.read('ccsdsday') \* 86400.0) + (packet.read('ccsdsmsod') / 1000.0) + (packet.read('ccsdsusoms') / 1000000.0))
GENERIC_READ_CONVERSION_END
ITEM TIMEFORMATTED 0 0 DERIVED "DERIVED TIME SINCE EPOCH AS A FORMATTED STRING"
GENERIC_READ_CONVERSION_START STRING 216
time = Time.ccsds2mdy(packet.read('ccsdsday'), packet.read('ccsdsmsod'), packet.read('ccsdsusoms'))
sprintf('%04u/%02u/%02u %02u:%02u:%02u.%06u', time[0], time[1], time[2], time[3], time[4], time[5], time[6])
GENERIC_READ_CONVERSION_END
{% endhighlight %}
