---
layout: news_item
title: 'Ball Aerospace COSMOS 3.7.0 Released'
date: 2015-11-25 12:00:00 -0700
author: ryanmelt
version: 3.7.0
categories: [release]
---

### New Features:

* [#213](https://github.com/BallAerospace/COSMOS/issues/213) Vertical Limits Bar
* [#214](https://github.com/BallAerospace/COSMOS/issues/214) TlmGrapher show full date for plotted points
* [#219](https://github.com/BallAerospace/COSMOS/issues/219) State Color Widget
* [#225](https://github.com/BallAerospace/COSMOS/issues/225) Set Bind Address in UDP interface

### Maintenance:

* [#223](https://github.com/BallAerospace/COSMOS/issues/223) C Extension Improvements

### Bug Fixes:

* [#199](https://github.com/BallAerospace/COSMOS/issues/199) Investigate TlmGrapher Formatted Time Item
* [#211](https://github.com/BallAerospace/COSMOS/issues/211) Background task with arguments not working
* [#217](https://github.com/BallAerospace/COSMOS/issues/217) Graph Right Margin Too Small

### Migration Notes from COSMOS 3.6.x:

1. Background task arguments are now broken out instead of being received as a single array
2. udp_interface now takes an optional argument for bind_address
3. line_graph_script has been significantly updated to support modifying plots from the script.
