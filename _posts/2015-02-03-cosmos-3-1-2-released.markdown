---
layout: news_item
title: 'Ball Aerospace COSMOS 3.1.2 Released'
date: 2015-02-03 12:00:00 -0700
author: ryanmelt
version: 3.1.2
categories: [release]
---

### Issues:

 * [#20](https://github.com/BallAerospace/COSMOS/issues/20) Handbook Creator should output relative paths
 * [#21](https://github.com/BallAerospace/COSMOS/issues/21) Improve code metrics
 * [#26](https://github.com/BallAerospace/COSMOS/issues/26) Dynamically created file for Mac launchers should not be included in CRC calculation
 * [#27](https://github.com/BallAerospace/COSMOS/issues/27) TestRunner build_test_suites destroys CustomTestSuite if underlying test procedures change
 * [#28](https://github.com/BallAerospace/COSMOS/issues/28) TlmGrapher - Undefined method nan? for 0:Fixnum
 * [#35](https://github.com/BallAerospace/COSMOS/issues/35) Race condition starting new binary log
 * [#36](https://github.com/BallAerospace/COSMOS/issues/36) TlmDetailsDialog non-functional
 * [#37](https://github.com/BallAerospace/COSMOS/issues/37) Remaining TlmGrapher regression
 * [#38](https://github.com/BallAerospace/COSMOS/issues/38) Allow INTERFACE_TARGET to work with target name substitutions

### Migration Notes from COSMOS 3.0.x:

The definition of limits persistence has changed. Before it only applied when changing to a bad state (yellow or red). Now persistence applies for all changes including from stale to a valid state and from bad states back to green.
