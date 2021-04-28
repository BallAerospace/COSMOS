---
layout: news_item
title: "Ball Aerospace COSMOS 4.2.2 Released"
date: 2018-04-11 6:00:00 -0700
author: ryanmelt
version: 4.2.2
categories: [release]
---

COSMOS 4.2 is here! Thirty four tickets went into this release, but the highlight is a new tool called the Data Archival and Retrieval Tool (DART). DART is a long term trending database built on top of the PostgreSql database. It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range. Queries are super fast and it performs automatic data reduction at minute/hour/day granularity. Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosc2.com/docs/home/

### New Features:

- [#698](https://github.com/BallAerospace/COSMOS/issues/698) Initial DART Release
- [#650](https://github.com/BallAerospace/COSMOS/issues/650) Gracefully handle large array items
- [#673](https://github.com/BallAerospace/COSMOS/issues/673) Button widget should spawn thread to avoid blocking GUI
- [#676](https://github.com/BallAerospace/COSMOS/issues/676) Allow individual interfaces to be disconnect mode
- [#699](https://github.com/BallAerospace/COSMOS/issues/699) Test cases added to TestRunner should be ordered in drop down
- [#705](https://github.com/BallAerospace/COSMOS/issues/705) Cmd line arg for ScriptRunner to start in disconnect mode
- [#706](https://github.com/BallAerospace/COSMOS/issues/706) Warn if ITEMs or PARAMETERs are redefined
- [#711](https://github.com/BallAerospace/COSMOS/issues/711) Allow ERB to know the target name
- [#715](https://github.com/BallAerospace/COSMOS/issues/715) Allow individual Limits Monitor items to be removed (not ignored)
- [#719](https://github.com/BallAerospace/COSMOS/issues/719) Warn if limits_group doesn't exist in limits_groups_background_task
- [#729](https://github.com/BallAerospace/COSMOS/issues/729) CmdSender production mode to disable MANUALLY ENTERED
- [#734](https://github.com/BallAerospace/COSMOS/issues/734) Support DERIVED with APPEND
- [#737](https://github.com/BallAerospace/COSMOS/issues/737) Implement single stepping with the F10 key
- [#754](https://github.com/BallAerospace/COSMOS/issues/754) Add Replay Mode to Include All Routers
- [#765](https://github.com/BallAerospace/COSMOS/issues/765) TlmGrapher sampled analysis

### Maintenance:

- [#682](https://github.com/BallAerospace/COSMOS/issues/682) Fix Ruby interpreter warnings
- [#687](https://github.com/BallAerospace/COSMOS/issues/687) Add ConfigEditor AHK tests
- [#688](https://github.com/BallAerospace/COSMOS/issues/688) Windows 10 Installation Error - RDoc parsing failure in qtruby4.rb
- [#692](https://github.com/BallAerospace/COSMOS/issues/692) Fix METADATA usage in demo
- [#738](https://github.com/BallAerospace/COSMOS/issues/738) PacketViewer scroll to item on search
- [#748](https://github.com/BallAerospace/COSMOS/issues/748) Syntax highlighting prioritizes string over comment
- [#750](https://github.com/BallAerospace/COSMOS/issues/750) TestRunner hides syntax errors with broad rescue
- [#752](https://github.com/BallAerospace/COSMOS/issues/752) Demo INST commanding screen broken
- [#757](https://github.com/BallAerospace/COSMOS/issues/757) Increase TlmGrapher timeout to better support Replay
- [#759](https://github.com/BallAerospace/COSMOS/issues/759) Allow underscores and dashes in log filename labels

### Bug Fixes:

- [#690](https://github.com/BallAerospace/COSMOS/issues/690) Automatic SYSTEM META definition doesn't include RECEIVED_XX
- [#691](https://github.com/BallAerospace/COSMOS/issues/691) tools/mac apps won't open
- [#701](https://github.com/BallAerospace/COSMOS/issues/701) XTCE String types should not have ByteOrderList
- [#709](https://github.com/BallAerospace/COSMOS/issues/709) Can't set breakpoint in subscript
- [#713](https://github.com/BallAerospace/COSMOS/issues/713) Launcher crashes if newline in crc.txt
- [#723](https://github.com/BallAerospace/COSMOS/issues/723) crc_protocol needs better input validation
- [#727](https://github.com/BallAerospace/COSMOS/issues/727) Install issue on Windows 10
- [#732](https://github.com/BallAerospace/COSMOS/issues/732) losing/gaining data when routing at different incoming rates
- [#735](https://github.com/BallAerospace/COSMOS/issues/735) Statistics Processor doesn't handle nil or infinite
- [#740](https://github.com/BallAerospace/COSMOS/issues/740) About dialog crashes if USER_VERSION not defined

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosc2.com/docs/home/
