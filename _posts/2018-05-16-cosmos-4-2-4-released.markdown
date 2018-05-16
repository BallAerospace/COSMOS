---
layout: news_item
title: 'Ball Aerospace COSMOS 4.2.4 Released'
date: 2018-05-16 6:00:00 -0700
author: ryanmelt
version: 4.2.4
categories: [release]
---

This is the second patch release for 4.2.  It greatly improves the ingest speed for DART (100x), improves decom speed, reduces database size, and fixes some bugs.  If you are using DART, please upgrade and follow the migration directions at the end of these release notes.

The highlight of COSMOS 4.2 is a new tool called the Data Archival and Retrieval Tool (DART).   DART is a long term trending database built on top of the PostgreSql database.  It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range.  Queries are super fast and it performs automatic data reduction at minute/hour/day granularity.  Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

### New Features:

* [#787](https://github.com/BallAerospace/COSMOS/issues/787) No way to control data bits on serial interface
* [#788](https://github.com/BallAerospace/COSMOS/issues/788) ROUTERS should support PROTOCOL keyword

### Maintenance:

* [#784](https://github.com/BallAerospace/COSMOS/issues/784) Comparable and spaceship operator behavior changing
* [#791](https://github.com/BallAerospace/COSMOS/issues/791) Table Manager doesn't expose top level layout

### Bug Fixes:

* [#779](https://github.com/BallAerospace/COSMOS/issues/779) Dart updates for ingest speed, correct time zone, TlmGrapher crash
* [#786](https://github.com/BallAerospace/COSMOS/issues/786) Status tab crash on Ruby 2.5
* [#790](https://github.com/BallAerospace/COSMOS/issues/790) Telemetry check doesn't support strings with multiple spaces

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

If you already setup DART for your program please follow the following additional steps:
In a terminal in your COSMOS project folder run:

```
rake db:migrate
rake db:seed
```

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/
