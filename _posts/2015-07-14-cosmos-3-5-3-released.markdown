---
layout: news_item
title: 'Ball Aerospace COSMOS 3.5.3 Released'
date: 2015-07-14 12:00:00 -0700
author: ryanmelt
version: 3.5.3
categories: [release]
---

### Bug Fixes:

* [#169](https://github.com/BallAerospace/COSMOS/issues/169) Make windows bat files support running outside of the current directory

### New Features:

* N/A

### Maintenance:

* N/A

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool. All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.1

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments. If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.
