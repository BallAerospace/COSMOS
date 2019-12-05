---
layout: docs
title: DART API
permalink: /docs/dart_api/
toc: true
---
DART (Data Archival Retrieval Trending) provides two client APIs to access the data. Decommutated data can be accessed by sending JSON requests to the DART Decommutation Server. A raw packet stream can also be accessed by sending JSON requests to the DART Stream Server.

## DART Decommutation Server

The DART Decommutation API implements a relaxed version of the [JSON-RPC 2.0 Specification](http://www.jsonrpc.org/specification). Requests with an "id" of NULL are not supported. Numbers can contain special non-string literal's such as NaN, and +/-inf. Request params must be specified by-position, by-name is not supported. Section 6 of the spec, Batch Operations, is not supported.

DART creates a HTTP Server at port 8779 by default to respond to request for decommutated data. Note that this can be changed by overriding the DART_DECOM port in the system.txt file. The server expects to receive JSON RPC formatted request to the "query" method with a since hash parameter with the following fields.

| Field Name | Description | Example | Required (Default) |
| ---------- | ----------- | --------|----------|
| start_time_sec | Unix start time in seconds (UTC) | 1514764800 (Jan 1, 2018 00:00:00) | Yes |
| start_time_usec | Microseconds part of the start time | 0 | Yes |
| end_time_sec | Unix end time in seconds (UTC) | 1514809815 (Jan 1, 2018 12:30:15) | Yes |
| end_time_usec | Microseconds part of the end time | 0 | Yes |
| item | Array specifying the target, packet, and item name | ['INST','HEALTH_STATUS','TEMP1'] | Yes |
| reduction | How to reduce the data | "NONE", "MINUTE", "HOUR", "DAY" | Yes |
| value_type | The type of data to return | "RAW", "RAW_MAX", "RAW_MIN", "RAW_AVG", "RAW_STDDEV", "CONVERTED", "CONVERTED_MAX", "CONVERTED_MIN", "CONVERTED_AVG", "CONVERTED_STDDEV" | Yes |
| cmd_tlm | Whether the request is for command or telemetry data | 'CMD' or 'TLM' | No ('TLM') |
| limit | Maximum number of data items to return. Must be less than or equal to 10000. | 100 | No (10000) |
| offset | Offset into the data stream. Since the maximum number of values allowed is 10000, you can set the offset to 10000, then 20000, etc to get additional values. | 10000 | No (0) |
| meta_filters | Array of logical meta data filter expressions. Supports logical assertions on all the defined SYSTEM META items in your COSMOS definition. Logical operators include '=' (or '==', both mean equals), '!= (not equal)', '>', '<', '>=', and '<='. | ["OPERATOR_NAME" == "Jason"] | No ([]) |
| meta_ids | Array of the meta ID(s) to use when filtering the data. The meta IDs are an internal DART ID and thus this is only used if you have obtained the database meta IDs from a previous DART Decommutation Server request. | 1 | No ([]) |

After sending the request, the JSON RPC response will contain an Array of Arrays containing the item value, item seconds, item microseconds, samples (always 1 for NONE reduction, varies for other reduction values), and meta_id. Note this meta_id is the ID which can be used in subsequent requests in the meta_ids field.

Example Usage:
{% highlight bash %}
--> {"jsonrpc": "2.0", "method": "query", "params": [{"start_time_sec": 1514764800, "start_time_usec": 0, "end_time_sec": 415000000, "end_time_usec": 0, "item": ["INST", "HEALTH_STATUS", "TEMP1"], "reduction": "NONE", "value_type": "CONVERTED"}], "id": 1}
<-- {"jsonrpc": "2.0", "result": [[10.3, 1514764800, 0, 1, 1], [15.6, 1514764801, 340, 1, 1]], "id": 1}
{% endhighlight %}

## DART Stream Server
DART creates a TCP/IP Server at port 8777 by default to respond to requests for a stream of raw COSMOS packet data. Note that this can be changed by overriding the DART_STREAM port in the system.txt file. The server expects to receive JSON formatted requests with the following fields.

| Field Name | Description | Example | Required (Default) |
| ---------- | ----------- | --------|----------|
| start_time_sec | Unix start time in seconds (UTC) | 1514764800 (Jan 1, 2018 00:00:00) | Yes |
| start_time_usec | Microseconds part of the start time | 0 | Yes |
| end_time_sec | Unix end time in seconds (UTC) | 1514809815 (Jan 1, 2018 12:30:15) | Yes |
| end_time_usec | Microseconds part of the end time | 0 | Yes |
| packets | Array of arrays specifying the target and packet name | [['INST','HEALTH_STATUS'], ['INST','ADCS']] | No (All Packets) |
| cmd_tlm | Whether the request is for command or telemetry data | 'CMD' or 'TLM' | No ('TLM') |
| meta_filters | Array of logical meta data filter expressions. Supports logical assertions on all the defined SYSTEM META items in your COSMOS definition. Logical operators include '=' (or '==', both mean equals), '!= (not equal)', '>', '<', '>=', and '<='. | ["OPERATOR_NAME" == "Jason"] | No ([]) |
| meta_ids | Array of the meta ID(s) to use when filtering the data. The meta IDs are an internal DART ID and thus this is only used if you have obtained the database meta IDs from a previous DART Decommutation Server request. | 1 | No ([]) |

After sending the request, the client should read from the same socket which will return COSMOS [Packets](/docs/packet_class) using the COSMOS PREIDENTIFIED stream format until the request has streamed all the requested packets.
