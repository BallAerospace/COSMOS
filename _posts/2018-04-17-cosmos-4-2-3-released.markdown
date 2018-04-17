---
layout: news_item
title: 'Ball Aerospace COSMOS 4.2.3 Released'
date: 2018-04-17 6:00:00 -0700
author: ryanmelt
version: 4.2.3
categories: [release]
---

COSMOS 4.2 is here!   This is the first true patch release for 4.2.  The highlight of COSMOS 4.2 is a new tool called the Data Archival and Retrieval Tool (DART).   DART is a long term trending database built on top of the PostgreSql database.  It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range.  Queries are super fast and it performs automatic data reduction at minute/hour/day granularity.  Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

### New Features:

* [#767](https://github.com/BallAerospace/COSMOS/issues/767) Support Ruby 2.5
* [#771](https://github.com/BallAerospace/COSMOS/issues/771) Add CmdSender Search

### Maintenance:

* [#772](https://github.com/BallAerospace/COSMOS/issues/772) OpenGL gem isn't supported in Ruby 2.5

### Bug Fixes:

* [#769](https://github.com/BallAerospace/COSMOS/issues/769) TIMEGRAPH widget non-functional
* [#775](https://github.com/BallAerospace/COSMOS/issues/775) Toggle disconnect broken in TestRunner

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/
