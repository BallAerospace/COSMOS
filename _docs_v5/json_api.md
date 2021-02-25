---
layout: docs
title: JSON API
---

<div class="note unreleased">
  <p>Update with COSMOS 5 changes to JSON API</p>
</div>

<div class="note">
  <h5>This documentation is for COSMOS Developers</h5>
  <p markdown="1">If you're looking for the methods available to write test procedures using the COSMOS scripting API, refer to the [Scripting Guide](/docs/v5/scripting) page. If you're trying to interface to a COSMOS Command and Telemetry Server from an external application using any language then this is the right place.</p>
</div>

This document provides the information necessary for external applications to interact with the COSMOS Command and Telemetry Server using the COSMOS API. External applications written in any language can send commands and retrieve individual telemetry points using this API. External applications also have the option of connecting to the COSMOS Command and Telemetry server to interact with raw tcp/ip streams of commands/telemetry. However, the COSMOS JSON API removes the requirement that external applications have knowledge of the binary formats of packets.

## JSON-RPC 2.0

The COSMOS API implements a relaxed version of the [JSON-RPC 2.0 Specification](http://www.jsonrpc.org/specification). Requests with an "id" of NULL are not supported. Numbers can contain special non-string literal's such as NaN, and +/-inf. Request params must be specified by-position, by-name is not supported. Section 6 of the spec, Batch Operations, is not supported.

## Socket Connections

The COSMOS Command and Telemetry Server listens for connections to the COSMOS API on an HTTP server (default port of 7777).

## Supported Methods

The list of methods supported by the COSMOS API may be found in the [api](https://github.com/BallAerospace/COSMOS/tree/master/cosmos/lib/cosmos/api) source code on Github. The @api_whitelist variable is initialized with an array of all methods accepted by the CTS. This page will not show the full argument list for every method in the API, but it should be noted that the JSON API methods correspond to the COSMOS scripting API methods documented in the [Scripting Guide](/docs/v5/scripting). This page will show a few example JSON requests and responses, and the scripting guide can be used as a reference to extrapolate how to build requests and parse responses for methods not explicitly documented here.

## Existing Implementations

The COSMOS JSON API has been implemented in the following languages:

- [Python](https://github.com/BallAerospace/python-ballcosmos)

## Example Usage

### Sending Commands

The following methods are used to send commands: cmd, cmd_no_range_check, cmd_no_hazardous_check, cmd_no_checks

The cmd method sends a command to a COSMOS target in the system. The cmd_no_range_check method does the same but ignores parameter range errors. The cmd_no_hazardous_check method does the same, but allows hazardous commands to be sent. The cmd_no_checks method does the same but allows hazardous commands to be sent, and ignores range errors.

Two parameter syntaxes are supported.

The first is a single string of the form "TARGET_NAME COMMAND_NAME with PARAMETER_NAME_1 PARAMETER_VALUE_1, PARAMETER_NAME_2 PARAMETER_VALUE_2, ..." The "with ..." portion of the string is optional. Any unspecified parameters will be given default values.

| Parameter      | Data Type | Description                                                         |
| -------------- | --------- | ------------------------------------------------------------------- |
| command_string | string    | A single string containing all required information for the command |

The second is two or three parameters with the first parameter being a string denoting the target name, the second being a string with the command name, and an optional third being a hash of parameter names/values. This format should be used if the command contains parameters that take binary data that is not capable of being expressed as ASCII text. The cmd and cmd_no_range_check methods will fail on all attempts to send a command that has been marked hazardous. To send hazardous commands, the cmd_no_hazardous_check, or cmd_no_checks methods must be used.

| Parameter      | Data Type | Description                               |
| -------------- | --------- | ----------------------------------------- |
| target_name    | String    | Name of the target to send the command to |
| command_name   | String    | The name of the command                   |
| command_params | Hash      | Optional hash of command parameters       |

Example Usage:
{% highlight bash %}
--> {"jsonrpc": "2.0", "method": "cmd", "params": ["INST COLLECT with DURATION 1.0, TEMP 0.0, TYPE 'NORMAL'"], "id": 1}
<-- {"jsonrpc": "2.0", "result": ["INST", "COLLECT", {"DURATION": 1.0, "TEMP": 0.0, "TYPE": "NORMAL"}], "id": 1}

--> {"jsonrpc": "2.0", "method": "cmd", "params": ["INST", "COLLECT", {"DURATION": 1.0, "TEMP": 0.0, "TYPE": "NORMAL"}], "id": 1}
<-- {"jsonrpc": "2.0", "result": ["INST", "COLLECT", {"DURATION": 1.0, "TEMP": 0.0, "TYPE": "NORMAL"}], "id": 1}
{% endhighlight %}

### Getting Telemetry

The following methods are used to get telemetry: tlm, tlm_raw, tlm_formatted, tlm_with_units

The tlm method returns the current converted value of a telemetry point. The tlm_raw method returns the current raw value of a telemetry point. The tlm_formatted method returns the current formatted value of a telemetry point. The tlm_with_units method returns the current formatted value of a telemetry point with its units appended to the end.

Two parameter syntaxes are supported.

The first is a single string of the form "TARGET_NAME PACKET_NAME ITEM_NAME"

| Parameter  | Data Type | Description                                                                |
| ---------- | --------- | -------------------------------------------------------------------------- |
| tlm_string | String    | A single string containing all required information for the telemetry item |

The second is three parameters with the first parameter being a string denoting the target name, the second being a string with the packet name, and the third being a string with the item name.

| Parameter   | Data Type | Description                                        |
| ----------- | --------- | -------------------------------------------------- |
| target_name | String    | Name of the target to get the telemetry value from |
| packet_name | String    | Name of the packet to get the telemetry value from |
| item_name   | String    | Name of the telemetry item                         |

Example Usage:
{% highlight bash %}
--> {"jsonrpc": "2.0", "method": "tlm", "params": ["INST HEALTH_STATUS TEMP1"], "id": 2}
<-- {"jsonrpc": "2.0", "result": 94.9438, "id": 2}

--> {"jsonrpc": "2.0", "method": "tlm", "params": ["INST", "HEALTH_STATUS", "TEMP1"], "id": 2}
<-- {"jsonrpc": "2.0", "result": 94.9438, "id": 2}
{% endhighlight %}

## Further Debugging

If developing an interface for the JSON API from another language, the best way to debug is to send the same messages from the supported Ruby interface first, like the following. By enabling the debug mode, you can see the exact request and response sent from the Ruby Implementation.

1. Launch CmdTlmServer
2. From a command line, launch ScriptRunner: ruby ScriptRunner
3. Run a script like the following:

{% highlight ruby %}
JsonDRb.debug = true
cmd("INST ARYCMD with ARRAY [1, 2, 3]")
{% endhighlight %}

4. The following will be printed to the terminal where you launched ScriptRunner:

{% highlight bash %}
Request:
{"jsonrpc":"2.0","method":"cmd","params":["INST ARYCMD with ARRAY [1, 2, 3]"],"id":0}
Response:
{"jsonrpc":"2.0","id":0,"result":["INST","ARYCMD",{"ARRAY":[1,2,3]}]}
{% endhighlight %}
