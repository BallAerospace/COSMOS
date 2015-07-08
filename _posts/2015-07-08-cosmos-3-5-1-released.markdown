---
layout: news_item
title: 'Ball Aerospace COSMOS 3.5.1 Released'
date: 2015-07-08 12:00:00 -0700
author: jmthomas
version: 3.5.1
categories: [release]
---

This release contains a simple bug fix which prevented the install and demo configurations from launching.

### Bug Fixes:

* [#165](https://github.com/BallAerospace/COSMOS/pull/165) Change launch_tool to tool_launch in Launcher

### New Features:

* None

### Maintenance:

* None

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool.  All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.0

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments.  If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.
