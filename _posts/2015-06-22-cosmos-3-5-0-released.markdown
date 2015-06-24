---
layout: news_item
title: 'Ball Aerospace COSMOS 3.5.0 Released'
date: 2015-06-22 12:00:00 -0700
author: ryanmelt
version: 3.5.0
categories: [release]
---

This release contains a lot of new functionality and a key new feature:  The ability to create new COSMOS targets and tools as reusable gems!  This will hopefully allow the open source community to create sharable configuration for a large amount of hardware and allow for community generated tools to be easily integrated.

### Bug Fixes:

* [#153](https://github.com/BallAerospace/COSMOS/issues/153) set_tlm should support settings strings with spaces using the normal syntax
* [#155](https://github.com/BallAerospace/COSMOS/issues/155) Default to not performing DNS lookups

### New Features:

* [#25](https://github.com/BallAerospace/COSMOS/issues/25) Warn users if reading a packet log uses the latest instead of the version specified in the file header
* [#106](https://github.com/BallAerospace/COSMOS/issues/106) Allow the server to run headless
* [#109](https://github.com/BallAerospace/COSMOS/issues/109) Cmd value api
* [#129](https://github.com/BallAerospace/COSMOS/issues/129) Script Runner doesn't syntax highlight module namespacing
* [#133](https://github.com/BallAerospace/COSMOS/issues/133) Add sound to COSMOS alerts
* [#138](https://github.com/BallAerospace/COSMOS/issues/138) Limits Monitor should show what is stale
* [#142](https://github.com/BallAerospace/COSMOS/issues/142) Support gem based targets and tools
* [#144](https://github.com/BallAerospace/COSMOS/issues/144) Never have nothing happen when trying to launch a tool
* [#152](https://github.com/BallAerospace/COSMOS/issues/152) Provide a method to retrieve current suite/group/case in TestRunner
* [#157](https://github.com/BallAerospace/COSMOS/issues/157) Launcher support command line options in combobox
* [#163](https://github.com/BallAerospace/COSMOS/issues/163) Allow message_box to display buttons vertically

### Maintenance:

* [#131](https://github.com/BallAerospace/COSMOS/issues/131) Consolidate Find/Replace logic in the FindReplaceDialog
* [#137](https://github.com/BallAerospace/COSMOS/issues/137) Improve Server message log performance
* [#142](https://github.com/BallAerospace/COSMOS/issues/142) Improve Windows Installer bat file
* [#146](https://github.com/BallAerospace/COSMOS/issues/146) Need support for additional non-standard serial baud rates
* [#150](https://github.com/BallAerospace/COSMOS/issues/150) Improve Win32 serial driver performance

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool.  All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.0

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments.  If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.
