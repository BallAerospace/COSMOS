---
layout: news_item
title: 'Ball Aerospace COSMOS 3.6.2 Released'
date: 2015-08-10 16:00:00 -0700
author: ryanmelt
version: 3.6.2
categories: [release]
---

Huge new feature in this release: All COSMOS configuration files are now interpreted with the ERB preprocessor!  This allows you to use Ruby code within the configuration files to help build them.  You can also render partials of common information such as packet headers so you only have to define them once.  See the INST target in the updated Demo project for examples.

### Bug Fixes:

* [#187](https://github.com/BallAerospace/COSMOS/issues/187) Must require tempfile in config_parser.rb on non-windows systems

### Migration Notes from COSMOS 3.5.x:

None
