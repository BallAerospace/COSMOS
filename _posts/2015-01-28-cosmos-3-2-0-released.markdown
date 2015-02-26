---
layout: news_item
title: 'Ball Aerospace COSMOS 3.2.0 Released'
date: 2015-02-17 12:00:00 -0700
author: ryanmelt
version: 3.2.0
categories: [release]
---

### Issues:

 * [#34](https://github.com/BallAerospace/COSMOS/issues/34) Refactor packet_config
 * [#43](https://github.com/BallAerospace/COSMOS/issues/43) Add ccsds_log_reader.rb as an example of alternative log readers
 * [#45](https://github.com/BallAerospace/COSMOS/issues/45) Slow shutdown of CTS and TlmViewer with threads trying to connect
 * [#46](https://github.com/BallAerospace/COSMOS/issues/46) Add mutex protection to Cosmos::MessageLog
 * [#47](https://github.com/BallAerospace/COSMOS/issues/47) TlmGrapher RangeError in Overview Graph
 * [#49](https://github.com/BallAerospace/COSMOS/issues/49) Make about dialog scroll
 * [#55](https://github.com/BallAerospace/COSMOS/issues/55) Automatic require of stream_protocol fix and cleanup
 * [#57](https://github.com/BallAerospace/COSMOS/issues/57) Add OPTION keyword to support passing arbitrary options to interfaces/routers
 * [#59](https://github.com/BallAerospace/COSMOS/issues/59) Add password mode to ask and ask_string

### Migration Notes from COSMOS 3.1.x:

No significant updates to existing code should be needed. The primary reason for update to 3.2.x is fixing the slow shutdown present in all of 3.1.x.
