---
layout: news_item
title: "Template Protocol"
date: 2017-06-19 00:00:00 -0700
author: jmthomas
categories: [post]
---

The [Template Protocol](/docs/protocols#template-protocol) is probably one of the more confusing protocols in the COSMOS protocol library but it is extremely helpful when implementing string based protocols such as Standard Commands for Programmable Instruments (SCPI; often pronounced "skippy").

For this example we'll assume we're trying to talk to a SCPI enabled power supply such as the Keysight N6700. We start by creating a directory under our config/targets called POWER. The supply has a TCP/IP interface so we'll use the [TCP/IP Client Interface](/docs/v4/interfaces#tcpip-client-interface) to connect to it. Thus we create our POWER/cmd_tlm_server.txt file as follows:

```
INTERFACE POWER_INT tcpip_client_interface.rb 127.0.0.1 5025 5025 10.0 nil TEMPLATE 0x0A 0x0A
  TARGET POWER
```

This definition declares an interface named POWER_INT using the TCP/IP client interface which connects to '127.0.0.1' (obviously you'll change this to your actual power supply IP addres) using a write and read port of 5025 (standard SCPI ports for Keysight instruments) with a write timeout of 10s and no read timeout (block on read). We specify the TEMPLATE protocol with both write and read termination characters of 0x0A (ASCII newline). Note the [TEMPLATE protocol](/docs/protocols#template-protocol) takes many additional parameters to allow you to work with off nominal protocol conditions.

Now you can define your target's command and telemetry definitions. We'll create example commands which get and set the voltage setting in our power supply. Create a POWER/cmd_tlm/cmd.txt file which has the following:

```
COMMAND POWER GET_VOLTAGE BIG_ENDIAN "Get voltage"
  APPEND_ID_PARAMETER CMD_ID 8 UINT 1 1 1 "Command Id" # Unique command ID
  APPEND_PARAMETER CHANNEL 8 UINT 1 4 1 "Channel"
  APPEND_PARAMETER CMD_TEMPLATE 512 STRING "MEAS:VOLT? (@<CHANNEL>)"
  APPEND_PARAMETER RSP_TEMPLATE 512 STRING "<VOLTAGE>"
  APPEND_PARAMETER RSP_PACKET 512 STRING "TLM"

COMMAND POWER SET_VOLTAGE BIG_ENDIAN "Set voltage"
  APPEND_ID_PARAMETER CMD_ID 8 UINT 2 2 2 "Command Id" # Unique command ID
  APPEND_PARAMETER CHANNEL 8 UINT 1 4 1 "Channel"
  APPEND_PARAMETER VOLTAGE 8 UINT 0 100 10 "Voltage"
  APPEND_PARAMETER CMD_TEMPLATE 512 STRING "VOLT <VOLTAGE>,(@<CHANNEL>)"
  APPEND_PARAMETER RSP_TEMPLATE 512 STRING "<SET_VOLTAGE>"
  APPEND_PARAMETER RSP_PACKET 512 STRING "TLM"
```

The CMD_ID parameter is defined by [APPEND_ID_PARAMETER](/docs/v4/command#append_id_parameter). This ID parameter is not used by the SCPI protocol but is needed for COSMOS to identify the command when it is logged. The CMD_TEMPLATE parameter is the actual SCPI command which is being sent to the target. Anything inside brackets <> will be replaced by the value in the named parameter. For example, both commands define the CHANNEL parameter and thus \<CHANNEL\> will be replaced by the value of that parameter when constructing the command. The RSP_TEMPLATE is the expected string response back from the target. This is parsed by pulling out values into the bracket delimited values. The RSP_PACKET defines the packet where the bracket delimited values are defined. So for our GET_VOLTAGE example we parse the VOLTAGE value and place it in the TLM packet.

Create a POWER/cmd_tlm/tlm.txt file to define the response telemetry:

```
TELEMETRY POWER TLM BIG_ENDIAN "Power Supply Telemetry"
  APPEND_ID_ITEM TLM_ID 32 INT 1 "Packet Identifier" # Unique telemetry ID
  APPEND_ITEM VOLTAGE 32 FLOAT "PS Measured Voltage"
    FORMAT_STRING "%0.3f"
    UNITS "Volts" "V"
  APPEND_ITEM SET_VOLTAGE 32 FLOAT "PS Set Voltage"
    FORMAT_STRING "%0.3f"
    UNITS "Volts" "V"
```

The TLM_ID item is defined by [APPEND_ID_ITEM](/docs/v4/telemetry#append_id_item). This ID item is not used by the SCPI protocol but is needed by COSMOS to decode this logged telemetry packet. The packet is named TLM which matches our RSP_PACKET definition in the commands. We define VOLTAGE and SET_VOLTAGE which also match the values used in the RSP_TEMPLATE parameters in our commands.

With Keysight supplies you can string together a bunch of SCIP commands in one CMD_TEMPLATE if you delimit them with semicolons. Then in the RSP_TEMPLATE you can break the response apart and set a bunch of telemetry items at once. For example:

```
COMMAND POWER GET_STATUS BIG_ENDIAN "Get status"
  APPEND_ID_PARAMETER CMD_ID 8 UINT 3 3 3 "Command Id" # Unique command ID
  APPEND_PARAMETER CHANNEL 8 UINT 1 4 1 "Channel"
  APPEND_PARAMETER CMD_TEMPLATE 512 STRING "MEAS:VOLT (@<CHANNEL>);CURR (@<CHANNEL>);POW (@<CHANNEL>)"
  APPEND_PARAMETER RSP_TEMPLATE 512 STRING "<VOLTAGE>,<CURRENT>,<POWER>"
  APPEND_PARAMETER RSP_PACKET 512 STRING "TLM"
```

The RSP_TEMPLATE expects to have three values delimited by the comma character. For this example to be complete you would also need to declare CURRENT and POWER items in the TLM packet.

Using the TEMPLATE processor can be complex but makes working with with string based command / response protocols like SCPI much easier.

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
