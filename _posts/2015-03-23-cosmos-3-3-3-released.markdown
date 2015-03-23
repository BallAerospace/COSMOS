---
layout: news_item
title: 'Ball Aerospace COSMOS 3.3.3 Released'
date: 2015-03-23 12:00:00 -0700
author: ryanmelt
version: 3.3.3
categories: [release]
---

### Issues:

* [#93](https://github.com/BallAerospace/COSMOS/issues/93) Derived items that return arrays are not formatted to strings bug
* [#94](https://github.com/BallAerospace/COSMOS/issues/94) JsonDRb retry if first attempt hits a closed socket bug
* [#96](https://github.com/BallAerospace/COSMOS/issues/96) Make max lines written to output a variable in ScriptRunnerFrame enhancement
* [#99](https://github.com/BallAerospace/COSMOS/issues/99) Increase Block Count in DataViewer

### Migration Notes from COSMOS 3.2.x:

System.telemetry.target_names and System.commands.target_names no longer contain the 'UNKNOWN' target.
