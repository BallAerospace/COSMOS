---
layout: news_item
title: 'Ball Aerospace COSMOS 4.3.0 Released'
date: 2018-08-30 6:00:00 -0700
author: ryanmelt
version: 4.3.0
categories: [release]
---

Welcome to COSMOS 4.3.0!   

The highlight of this release is built in support for differentiating between stored telemetry and realtime telemetry.  If your system downlinks stored telemetry that you don't want to interfere with the COSMOS realtime current value table, your interface/protocol code can set the stored flag on a packet before returning it to COSMOS to have COSMOS log the packet, but not update the current telemetry values.     

Lots of other new features as well, and a few bug fixes including fixing running on the latest version of Mac OSX.  See below for the full list.

Breaking Changes:
The COSMOS log file format and predentified protocol formats have changed to support stored telemetry.   COSMOS 4.3 is backwards compatible with earlier formats, but older versions of COSMOS won't be able to read files from COSMOS 4.3+.

### New Features:

* [#780](https://github.com/BallAerospace/COSMOS/issues/780) Search bar support for Command Sequence
* [#785](https://github.com/BallAerospace/COSMOS/issues/785) Adjust font size
* [#804](https://github.com/BallAerospace/COSMOS/issues/804) Add classification bar to all tools
* [#808](https://github.com/BallAerospace/COSMOS/issues/808) Add CANVASELLIPSE widget
* [#814](https://github.com/BallAerospace/COSMOS/issues/814) Changes to support stored telemetry
* [#815](https://github.com/BallAerospace/COSMOS/issues/815) Create a temporary screen from a script
* [#818](https://github.com/BallAerospace/COSMOS/issues/818) Catch all state for any undefined state values
* [#819](https://github.com/BallAerospace/COSMOS/issues/819) Ensure x values added in incrementing order in TlmGrapher
* [#823](https://github.com/BallAerospace/COSMOS/issues/823) Add protocol to ignore any packet
* [#826](https://github.com/BallAerospace/COSMOS/issues/826) Allow hash style access to Excel
* [#829](https://github.com/BallAerospace/COSMOS/issues/829) Add STAY_ON_TOP feature to telemetry screens
* [#851](https://github.com/BallAerospace/COSMOS/issues/851) Ensure step_mode displays Step button
* [#859](https://github.com/BallAerospace/COSMOS/issues/859) Change Script Runner highlight color when paused

### Maintenance:

* [#796](https://github.com/BallAerospace/COSMOS/issues/796) Handle Command Sequence Export Issues
* [#807](https://github.com/BallAerospace/COSMOS/issues/807) Revert Items with STATE cannot define FORMAT_STRING
* [#812](https://github.com/BallAerospace/COSMOS/issues/812) Ruby 2.5 Instrumented Code outside of methods in a class
* [#855](https://github.com/BallAerospace/COSMOS/issues/855) Remove Qt warning message on Windows 10
* [#858](https://github.com/BallAerospace/COSMOS/issues/858) Fix JRuby build issues

### Bug Fixes:

* [#837](https://github.com/BallAerospace/COSMOS/issues/837) Packet Viewer's "Hide Ignored Items" Incorrectly Persists Across Change of Packet
* [#840](https://github.com/BallAerospace/COSMOS/issues/840) Latest version of COSMOS crashing
* [#845](https://github.com/BallAerospace/COSMOS/issues/845) Support get_tlm_details in disconnect mode

### Migration Notes from COSMOS 4.2.x:
To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/