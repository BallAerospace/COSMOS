---
layout: news_item
title: 'Ball Aerospace COSMOS 4.4.2 Released'
date: 2020-03-09 6:00:00 -0700
author: ryanmelt
version: 4.4.2
categories: [release]
---

COSMOS 4.4.2!   A minor bug fix release.

Enjoy and see below for the full list of changes.

### New Features:

None

### Maintenance:
* [#1117](https://github.com/BallAerospace/COSMOS/issues/1117) Include name in TcpipServerInteface log messages
* [#1128](https://github.com/BallAerospace/COSMOS/issues/1128) wkhtmltopdf has old comment

### Bug Fixes:

* [#1126](https://github.com/BallAerospace/COSMOS/issues/1126) Packets with identically named items fail checks

### Migration Notes from COSMOS 4.3.0:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

The faster identification in ticket #911 does come with a potentially breaking change.  The improvement requires that all packets for a given target be identified using the same fields (bit offset, bit_size, and type).   This is the typical configuration, and breaking this pattern is typically a dangerous/bad choice for interfaces anyways, but previously COSMOS did default to handling packets being potentially identified using different fields in the same target.  If you have a target that still requires that functionality, you need to declare CMD_UNIQUE_ID_MODE, and/or TLM_UNIQUE_ID_MODE in the target's target.txt file to indicate it should use the slower identification method.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/
