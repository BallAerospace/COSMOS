---
layout: news_item
title: 'Ball Aerospace COSMOS 3.6.0 Released'
date: 2015-08-07 12:00:00 -0700
author: ryanmelt
version: 3.6.0
categories: [release]
---

Huge new feature in this release: All COSMOS configuration files are now interpreted with the ERB preprocessor!  This allows you to use Ruby code within the configuration files to help build them.  You can also render partials of common information such as packet headers so you only have to define them once.  See the INST target in the updated Demo project for examples.

### Bug Fixes:

* [#168](https://github.com/BallAerospace/COSMOS/issues/168) Select unreliably unblocks when closing sockets on linux
* [#177](https://github.com/BallAerospace/COSMOS/issues/177) MACRO_APPEND in descending order is broken
* [#179](https://github.com/BallAerospace/COSMOS/issues/179) ScriptRunnerFrame Context Menu Crash
* [#182](https://github.com/BallAerospace/COSMOS/issues/182) Overriding LOG_WRITERS in cmd_tlm_server.txt can cause issues

### New Features:

* [#170](https://github.com/BallAerospace/COSMOS/issues170) Consider supporting a preprocessor over COSMOS config files
* [#171](https://github.com/BallAerospace/COSMOS/issues/171) Script Runner should have file open and save GUI dialogs
* [#174](https://github.com/BallAerospace/COSMOS/issues/174) Add View in Command Sender in Server

### Maintenance:

* [#80](https://github.com/BallAerospace/COSMOS/issues/80) Investigate performance of nonblocking IO without exceptions

### Migration Notes from COSMOS 3.5.x:

None
