---
layout: docs
title: DART API
permalink: /docs/dart_api/
toc: true
---
DART (Data Archival Retrieval Trending) provides two client APIs to access the data. Decommutated data can be accessed by sending JSON requests to the DART Decommutation Server. Raw data can be accessed by sending JSON requests to the DART Stream Server.

## DART Decommutation Server
DART creates a TCP/IP Server at port 8777 by default to respond to request for decommutated data. Note that this can be changed by overriding the DART_DECOM port in the system.txt file. The server expects to receive JSON formatted requests with the following fields.

| Field Name | Description | Example | Required (Default) |
| ---------- | ----------- | --------|----------|
| start_time_sec | Unix start time in seconds (UTC) | 1514764800 (Jan 1, 2018 00:00:00) | Yes |
| start_time_usec | Microseconds part of the start time | 0 | Yes |
| end_time_sec | Unix end time in seconds (UTC) | 1514809815 (Jan 1, 2018 12:30:15) | Yes |
| end_time_usec | Microseconds part of the end time | 0 | Yes |
| item | Array specifying the target, packet, and item name | ['INST','HEALTH_STATUS','TEMP1'] | Yes |
| reduction | How to reduce the data | "NONE", "MINUTE", "HOUR", "DAY" | Yes |
| value_type | The type of data to return | "RAW", "RAW_MAX", "RAW_MIN", "RAW_AVG", "CONVERTED", "CONVERTED_MAX", "CONVERTED_MIN", "CONVERTED_AVG" | Yes |
| cmd_tlm | Whether the request is for command or telemetry data | 'CMD' or 'TLM' | No ('TLM') |
| limit | Maximum number of data items to return. Must be less than 10000. | 100 | No (10000) |
| offset | Offset into the data stream. Since the maximum number of values allowed is 10000, you can set the offset to 10000, then 20000, etc to get additional values. | 10000 | No (0) |
| meta_ids | Array of the meta ID(s) to use when filtering the data. The meta IDs are an internal DART ID and thus this is only used if you have obtained the database meta IDs from a previous DART Decommutation Server request. | 1 | No ([]) |

After sending the request, the client should read from the same socket which will return an Array of Arrays containing the item name, item seconds, item microseconds, samples (always 1 for NONE reduction, varies for other reduction values), and meta_id. Note this meta_id is the ID which would be used in subsequent requests in the meta_ids field.

## DART Stream Server
DART creates a TCP/IP Server at port 8779 by default to respond to requests for raw COSMOS packet data. Note that this can be changed by overriding the DART_STREAM port in the system.txt file. The server expects to receive JSON formatted requests with the following fields.

| Field Name | Description | Example | Required (Default) |
| ---------- | ----------- | --------|----------|
| start_time_sec | Unix start time in seconds (UTC) | 1514764800 (Jan 1, 2018 00:00:00) | Yes |
| start_time_usec | Microseconds part of the start time | 0 | Yes |
| end_time_sec | Unix end time in seconds (UTC) | 1514809815 (Jan 1, 2018 12:30:15) | Yes |
| end_time_usec | Microseconds part of the end time | 0 | Yes |
| packets | Array of arrays specifying the target and packet name | [['INST','HEALTH_STATUS'], ['INST','ADCS']] | Yes |
| cmd_tlm | Whether the request is for command or telemetry data | 'CMD' or 'TLM' | No ('TLM') |
| meta_filters | Array of logical meta data filter expressions. Supports logical assertions on all the defined SYSTEM META items in your COSMOS definition. Logical operators include '=' (or '==', both mean equals), '!= (not equal)', '>', '<', '>=', and '<='. | ["OPERATOR_NAME" == "Jason"] | No ([]) |
| meta_ids | Array of the meta ID(s) to use when filtering the data. The meta IDs are an internal DART ID and thus this is only used if you have obtained the database meta IDs from a previous DART Decommutation Server request. | 1 | No ([]) |

After sending the request, the client should read from the same socket which will return COSMOS  [Packets](/docs/packet_class) in batches of 100 until the request has streamed all the requested packets.

TBD: Something about identified vs unidentified packets. Why / how?