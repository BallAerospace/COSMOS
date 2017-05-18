---
layout: news_item
title: 'Ball Aerospace COSMOS 3.7.1 Released'
date: 2015-12-29 12:00:00 -0700
author: ryanmelt
version: 3.7.1
categories: [release]
---

### Bug Fixes:

* [#228](https://github.com/BallAerospace/COSMOS/issues/228) Fix typo in udp_interface
* [#231](https://github.com/BallAerospace/COSMOS/issues/231) MACRO_APPEND with multiple items not working
* [#235](https://github.com/BallAerospace/COSMOS/issues/235) Improve IntegerChooser and FloatChooser Validation
* [#236](https://github.com/BallAerospace/COSMOS/issues/236) TestRunner doesn't support status_bar
* [#240](https://github.com/BallAerospace/COSMOS/issues/240) Make sure super() is called in all bundled conversion classes
* [#241](https://github.com/BallAerospace/COSMOS/issues/241) Don't reformat BLOCK data types with a conversion in Structure#formatted

### Migration Notes from COSMOS 3.6.x:

1. Background task arguments are now broken out instead of being received as a single array
2. udp_interface now takes an optional argument for bind_address
3. line_graph_script has been significantly updated to support modifying plots from the script.
