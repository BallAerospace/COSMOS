---
layout: docs
title: DART Design
permalink: /docs/dart_design/
toc: true
---
DART (Data Archival Retrieval Trending) is the COSMOS tool to support long term storage and trending of telemetry data. It was built on top of the open source PostgreSQL database to ensure rapid retrieval of data over long periods. The way it achieves this performance is to do data reduction on the original data at time periods of every minute, hour, and day. Thus to retrieve a year's worth of data the database simply has to return 365 telemetry items. The original data is always preserved for in debth analysis over specific time periods.
