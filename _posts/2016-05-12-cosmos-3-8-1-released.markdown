---
layout: news_item
title: 'Ball Aerospace COSMOS 3.8.1 Released'
date: 2016-05-12 12:00:00 -0700
author: ryanmelt
version: 3.8.1
categories: [release]
---

### New Features:

* [#184](https://github.com/BallAerospace/COSMOS/issues/184) Limits Monitor show green for blue limits items
* [#190](https://github.com/BallAerospace/COSMOS/issues/190) Simpler MIN MAX syntax for command definitions
* [#254](https://github.com/BallAerospace/COSMOS/issues/254) Get buffer from commands
* [#259](https://github.com/BallAerospace/COSMOS/issues/259) Proper support for user selected text editor on linux
* [#262](https://github.com/BallAerospace/COSMOS/issues/262) PackerViewer option for listing derived items last
* [#271](https://github.com/BallAerospace/COSMOS/issues/271) Time.formatted option for no microseconds
* [#288](https://github.com/BallAerospace/COSMOS/issues/288) check_tolerance should enforce a positive tolerance
* [#301](https://github.com/BallAerospace/COSMOS/issues/301) Update use of COSMOS_DEVEL

### Maintenance:

* [#268](https://github.com/BallAerospace/COSMOS/issues/268) xtce_converter doesn't support byte order list
* [#277](https://github.com/BallAerospace/COSMOS/issues/277) Test Runner support for Script Runner options
* [#285](https://github.com/BallAerospace/COSMOS/issues/285) xtce converter doesn't support LocationInContainerInBits

### Bug Fixes:

* [#256](https://github.com/BallAerospace/COSMOS/issues/256) Defining initialize method in Cosmos::Test class breaks the class when using Test Selection in TestRunner
* [#273](https://github.com/BallAerospace/COSMOS/issues/273) Wrap Qt::Application.instance in main_thread
* [#287](https://github.com/BallAerospace/COSMOS/issues/287) Installer issue on newer versions of Ubuntu and Debian related to libssl
* [#293](https://github.com/BallAerospace/COSMOS/issues/293) Units applied after a read_conversion that returns a string modifies cached conversion value
* [#294](https://github.com/BallAerospace/COSMOS/issues/294) String#convert_to_value should always just return the starting string if the conversion fails
* [#298](https://github.com/BallAerospace/COSMOS/issues/298) COSMOS IoMultiplexer breaks gems that invoke stream operator on STDOUT/ERR

### Migration Notes from COSMOS 3.7.x:
None
