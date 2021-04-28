---
layout: news_item
title: "Ball Aerospace COSMOS 3.8.3 Released"
date: 2016-12-06 12:00:00 -0700
author: ryanmelt
version: 3.8.3
categories: [release]
---

### New Features:

- [#230](https://github.com/BallAerospace/COSMOS/issues/230) Make AUTO_TARGETS ignore target folders that have already been manually referenced
- [#257](https://github.com/BallAerospace/COSMOS/issues/257) Increment received_count in packet log reader
- [#264](https://github.com/BallAerospace/COSMOS/issues/264) Validate command/telemetry conversions during startup
- [#292](https://github.com/BallAerospace/COSMOS/issues/292) Target directory for API methods
- [#314](https://github.com/BallAerospace/COSMOS/issues/314) Update .bat files to handle spaces in path
- [#316](https://github.com/BallAerospace/COSMOS/issues/316) Add option to radiobutton widget to be checked by default
- [#326](https://github.com/BallAerospace/COSMOS/issues/326) Script Runner Crash using message_box with boolean parameter
- [#339](https://github.com/BallAerospace/COSMOS/issues/339) Add 'Help' menu item to open cosmosc2.com -> Documentation
- [#340](https://github.com/BallAerospace/COSMOS/issues/340) Packet Viewer - Allow select cell and copy value as text
- [#357](https://github.com/BallAerospace/COSMOS/issues/357) Add support for mixed endianness within tables
- [#359](https://github.com/BallAerospace/COSMOS/issues/359) Table Manager support MIN/MAX UINTX macros

### Maintenance:

- [#349](https://github.com/BallAerospace/COSMOS/issues/349) Optimize cmd() to not build commands twice
- [#362](https://github.com/BallAerospace/COSMOS/issues/362) restore_defaults should take an optional parameter to exclude specified parameters
- [#365](https://github.com/BallAerospace/COSMOS/issues/365) Windows installer can have issues if .gem files are present in same folder
- TestRunner support for newer Bundler (Abstract error when starting)

### Bug Fixes:

- [#322](https://github.com/BallAerospace/COSMOS/issues/322) Udp interface thread does not gracefully shutdown
- [#327](https://github.com/BallAerospace/COSMOS/issues/327) TlmGrapher Screenshot in Linux captures the screenshot dialog box
- [#332](https://github.com/BallAerospace/COSMOS/issues/332) ERB template local variables dont' support strings
- [#338](https://github.com/BallAerospace/COSMOS/issues/338) Setting received_time and received_count on a packet should clear the read conversion cache
- [#342](https://github.com/BallAerospace/COSMOS/issues/342) Cut and Paste Error in top_level.rb
- [#344](https://github.com/BallAerospace/COSMOS/issues/344) CmdTlmServer connect/disconnect button doesn't work after calling connect_interface from script
- [#359](https://github.com/BallAerospace/COSMOS/issues/359) Table Manager doesn't support strings
- [#372](https://github.com/BallAerospace/COSMOS/issues/372) TestRunner reinstantiating TestSuite/Test objects every execution

### Migration Notes from COSMOS 3.7.x:

None

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
