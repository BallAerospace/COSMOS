---
layout: news_item
title: 'Ball Aerospace COSMOS 4.1.0 Released'
date: 2017-11-17 12:00:00 -0700
author: ryanmelt
version: 4.1.0
categories: [release]
---

Welcome to COSMOS 4.1!  The COSMOS API has transitioned from a custom TCP protocol to HTTP.  This will make interfacing to COSMOS from programming languages other than Ruby much easier.  There are also many new APIs that allows the full functionality of the CmdTlmServer and Replay to be controlled remotely.  See below for the full list of changes!

### New Features:

* [#531](https://github.com/BallAerospace/COSMOS/issues/531) Command sequence export option
* [#558](https://github.com/BallAerospace/COSMOS/issues/558) subscription APIs should work in disconnect mode
* [#559](https://github.com/BallAerospace/COSMOS/issues/559) Build Replay Functionality into CmdTlmServer
* [#578](https://github.com/BallAerospace/COSMOS/issues/578) Add ability to query available screens from Telemetry Viewer
* [#579](https://github.com/BallAerospace/COSMOS/issues/579) Create zip of configuration in saved config
* [#581](https://github.com/BallAerospace/COSMOS/issues/581) Make various log files readonly
* [#587](https://github.com/BallAerospace/COSMOS/issues/587) AUTO_INTERFACE_TARGETS ignore existing interfaces
* [#591](https://github.com/BallAerospace/COSMOS/issues/591) Investigate creating single COSMOS UDP socket for case where read_port == write_src_port
* [#599](https://github.com/BallAerospace/COSMOS/issues/599) Create subscription API for CTS messages
* [#601](https://github.com/BallAerospace/COSMOS/issues/601) Add background task and other status APIs
* [#606](https://github.com/BallAerospace/COSMOS/issues/606) Enhancement to Open File Script Interface - File Filter
* [#612](https://github.com/BallAerospace/COSMOS/issues/612) CSV support for strings and symbols
* [#620](https://github.com/BallAerospace/COSMOS/issues/620) Move Script Runner step button next to start/go
* [#625](https://github.com/BallAerospace/COSMOS/issues/625) Add APIs to start/stop background tasks
* [#626](https://github.com/BallAerospace/COSMOS/issues/626) Add API functions to get ignored parameters/items
* [#635](https://github.com/BallAerospace/COSMOS/issues/635) get_cmd_param_list should return the type for each command parameter
* [#642](https://github.com/BallAerospace/COSMOS/issues/642) Handle Infinity/NaN without invalid JSON

### Maintenance:

* [#510](https://github.com/BallAerospace/COSMOS/issues/510) Investigate changing JsonDrb to running over HTTP
* [#603](https://github.com/BallAerospace/COSMOS/issues/603) CmdTlmServer invalid constructor argument
* [#614](https://github.com/BallAerospace/COSMOS/issues/614) Pass server message color to message subscriptions
* [#619](https://github.com/BallAerospace/COSMOS/issues/619) Script Runner instrumenting comments and whitespace
* [#630](https://github.com/BallAerospace/COSMOS/issues/630) Add ConfigEditor and CmdSequence to install launcher
* [#647](https://github.com/BallAerospace/COSMOS/issues/647) Make packet item sort consistent
* [#649](https://github.com/BallAerospace/COSMOS/issues/649) Add codecov support

### Bug Fixes:

* [#562](https://github.com/BallAerospace/COSMOS/issues/562) #562 Template protocol should fill Id fields
* [#577](https://github.com/BallAerospace/COSMOS/issues/577) #577 Telemetry Viewer has fatal exception when called with JSON-RPC method display
* [#593](https://github.com/BallAerospace/COSMOS/issues/593) #593 Race condition in Cosmos.kill_thread
* [#607](https://github.com/BallAerospace/COSMOS/issues/607) #607 Support latest version of wkhtmltopdf for pdf creation and properly set working dir
* [#610](https://github.com/BallAerospace/COSMOS/issues/610) #610 target shouldn't report error requiring file in target lib
* [#616](https://github.com/BallAerospace/COSMOS/issues/616) #616 Ignore untested Windows version message in Windows 10
* [#617](https://github.com/BallAerospace/COSMOS/issues/617) #617 Ruby 2.4's inherent Warning class shadows Qt::MessageBox::Warning
* [#633](https://github.com/BallAerospace/COSMOS/issues/633) #633 combo_box is mutating input
* [#639](https://github.com/BallAerospace/COSMOS/issues/639) #639 Partial rendering in config parser should enforce that rendered partials start with underscore
* [#654](https://github.com/BallAerospace/COSMOS/issues/654) #654 Test Runner crashes with no config file
* [#655](https://github.com/BallAerospace/COSMOS/issues/655) #655 Metadata system triggers a nil router error in api.rb with basic setup
* [#659](https://github.com/BallAerospace/COSMOS/issues/659) #659 Hazardous commands throwing errors

### Migration Notes from COSMOS 4.0.x:

Any custom tools in other languages that use the COSMOS API will need to be updated. 

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
