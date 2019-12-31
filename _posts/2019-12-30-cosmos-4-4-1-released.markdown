---
layout: news_item
title: 'Ball Aerospace COSMOS 4.4.1 Released'
date: 2019-12-30 6:00:00 -0700
author: ryanmelt
version: 4.4.1
categories: [release]
---

Onward to COSMOS 4.4.1!   27 tickets have been incorporated including 6 new features, 13 bug fixes and 8 general maintenance changes.

Mainly a stability bug fix release, but there are a few cool changes.  There is an new keyword for marking that bit overlaps are intentional in packet definition files.  This can get rid of those annoying warnings when you do this intentionally.  There is also a new DELETE_ITEM keyword to get rid of items potentially added by auto generation.   Tlm Extractor and Tlm Grapher can now pull more than 10,000 data points from DART.   Also, there is now the ability to package multiple targets into one gem. 

Enjoy and see below for the full list of changes.

### New Features:

* [#817](https://github.com/BallAerospace/COSMOS/issues/817) Allow for intentional bit overlaps in definition
* [#821](https://github.com/BallAerospace/COSMOS/issues/821) Support DART queries larger than 10000 samples in TlmExtractor / TlmGrapher
* [#922](https://github.com/BallAerospace/COSMOS/issues/922) DELETE_ITEM
* [#1028](https://github.com/BallAerospace/COSMOS/issues/1028) Support Multiple Targets Packaged into Single Gem
* [#1040](https://github.com/BallAerospace/COSMOS/issues/1040) Config Editor new system config wizard
* [#1104](https://github.com/BallAerospace/COSMOS/issues/1104) Create releases from Docker

### Maintenance:

* [#1016](https://github.com/BallAerospace/COSMOS/issues/1016) Make JSON RPC API Command Methods Case Insensitive
* [#1030](https://github.com/BallAerospace/COSMOS/issues/1030) Scrolling in config editor can cause issues
* [#1039](https://github.com/BallAerospace/COSMOS/issues/1039) Config Editor performance enhancements
* [#1056](https://github.com/BallAerospace/COSMOS/issues/1056) AppVeyer broken
* [#1074](https://github.com/BallAerospace/COSMOS/issues/1074) For BLOCK parameters, suggest 0x0 as default value
* [#1080](https://github.com/BallAerospace/COSMOS/issues/1080) DART stream server docs
* [#1090](https://github.com/BallAerospace/COSMOS/issues/1090) DART Reduction unreliable with file imported data
* [#1101](https://github.com/BallAerospace/COSMOS/issues/1101) Windows 10 Install Error?

### Bug Fixes:

* [#883](https://github.com/BallAerospace/COSMOS/issues/883) DART meta filter not populating
* [#944](https://github.com/BallAerospace/COSMOS/issues/944) DART data retrievals not per packet_time
* [#1012](https://github.com/BallAerospace/COSMOS/issues/1012) Screens can't call display when launched with --screen
* [#1031](https://github.com/BallAerospace/COSMOS/issues/1031) Graphing a telemetry member whose name includes brackets fails
* [#1036](https://github.com/BallAerospace/COSMOS/issues/1036) TestRunner: ABORT_TESTING_AFTER_ERROR ignored for test cases added indivually to testsuite
* [#1037](https://github.com/BallAerospace/COSMOS/issues/1037) telemetry#all_item_strings support undeclared target names
* [#1051](https://github.com/BallAerospace/COSMOS/issues/1051) Windows serial port hangs on write
* [#1061](https://github.com/BallAerospace/COSMOS/issues/1061) Excel can't open a blank worksheet
* [#1063](https://github.com/BallAerospace/COSMOS/issues/1063) Length Protocol does not handle 0 length
* [#1064](https://github.com/BallAerospace/COSMOS/issues/1064) Command Sequence Repeating Write_Conversion
* [#1081](https://github.com/BallAerospace/COSMOS/issues/1081) Ruby Syntax Error Checker Hangs Test Runner
* [#1087](https://github.com/BallAerospace/COSMOS/issues/1087) COSMOS Installation failure in building puma_http11
* [#1092](https://github.com/BallAerospace/COSMOS/issues/1092) Typo in Odd Parity

### Migration Notes from COSMOS 4.3.0:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

The faster identification in ticket #911 does come with a potentially breaking change.  The improvement requires that all packets for a given target be identified using the same fields (bit offset, bit_size, and type).   This is the typical configuration, and breaking this pattern is typically a dangerous/bad choice for interfaces anyways, but previously COSMOS did default to handling packets being potentially identified using different fields in the same target.  If you have a target that still requires that functionality, you need to declare CMD_UNIQUE_ID_MODE, and/or TLM_UNIQUE_ID_MODE in the target's target.txt file to indicate it should use the slower identification method.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/
