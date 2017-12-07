---
layout: news_item
title: 'Ball Aerospace COSMOS 4.1.1 Released'
date: 2017-12-07 12:00:00 -0700
author: ryanmelt
version: 4.1.1
categories: [release]
---

### New Features:

* [#663](https://github.com/BallAerospace/COSMOS/issues/663) Built-in protocols to support allow_empty_data
* [#666](https://github.com/BallAerospace/COSMOS/issues/666) Add ability to create target in ConfigEditor
* [#679](https://github.com/BallAerospace/COSMOS/issues/679) TlmViewer screen audit shouldn't count reserved item names

### Maintenance:

* [#660](https://github.com/BallAerospace/COSMOS/issues/660) Update Opengl gem requirement version
* [#665](https://github.com/BallAerospace/COSMOS/issues/665) Refactor xtce parser

### Bug Fixes:

#661 

* [#661](https://github.com/BallAerospace/COSMOS/issues/661) Render function bug?

### Migration Notes from COSMOS 4.0.x:

Any custom tools in other languages that use the COSMOS API will need to be updated. 

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
