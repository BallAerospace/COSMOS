---
layout: docs
title: DART Design
permalink: /docs/dart_design/
toc: true
---
DART (Data Archival Retrieval Trending) is the COSMOS tool to support long term storage and trending of command and telemetry data. It was built on top of the open source PostgreSQL database to ensure rapid retrieval of data over long periods. Data is reducted at time periods of every minute, hour, and day to allow for increased performance of long queries. With this reduction, to return a reduced year's worth of data the database simply has to return 365 telemetry items. The original data is always preserved for indepth analysis over specific time periods.

## Overall Architecture and Context Diagram

The following diagram shows how DART integrates into a COSMOS System:

<img src="/img/DART_Architecture.png" alt="DART Architecture">

Key aspects of this architecture:

 * DART Contains 7 different applications
     * DART Process Monitor - Cleans the database and starts the next five applications / monitors aliveness
     * DART Ingester - Connects to the COSMOS CmdTlmServer and receives realtime cmd/tlm packets
     * DART Workers - Decommutates packets and save the decommutated data into the PostgreSql database
     * DART Reducer - Reduces decommutated data into minute/hour/day reduced data sets
     * DART Stream Server - Serves a stream of raw packets from DART on request
     * DART Decom Server - Provides a JSON formatted array of decommutated or reduced data for an item on request
     * DART Import - Command line tool to import previously logged data into DART
 * The COSMOS Command and Telemetry Server nominally streams data to DART in realtime. This keeps the data in DART as fresh as possible
 * Alternatively, or after an outage, data can be ingested into DART using the dart_import utility
 * TlmGrapher and TlmExtractor can pull decommutated or reduced data from the DART Decom Server
 * Replay, DataViewer, and CmdExtractor can pull a stream of raw packets from the DART Stream Server
 * Other telemetry tools can receive data from DART through Replay
 * Raw packets are stored in DART in normal COSMOS binary packet log files.  The PostgreSql database keeps indexes into these files that point to each packet for quick random access.  
 * Decommutated and Reduced data sets are stored directly in the PostgreSql database
 * Only integer and floating point data types are reduced into averages, minimum, maximum, and standard deviation at minute/hour/day granularities.

## Using the dart_import utility

Dart Import is used to import COSMOS command and telemetry packet log files into the DART system. This is useful for importing older data that was never imported for whatever reason, or if DART was offline when the data was collected. Important: These log files are imported in place and become part of the DART database.  The files must be placed into the DART data folder (defaults to outputs/dart/data) before they can be imported. Note that the data requires a SYSTEM META packet, and therefore generally only supports data from COSMOS 4.1.1+ unless the data is massaged first.

Usage:

```
dart_import <filename> [--force]
```

The --force flag can be used to force data to be reimported into the database even if the tool determines that all of the data is already likely in place. It still performs an algorithm to prevent duplicate data from being inserted into the database, but will check every single packet to make sure it is already in the database.


