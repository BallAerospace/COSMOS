---
layout: news_item
title: 'Ball Aerospace COSMOS 3.9.2 Released'
date: 2017-05-18 12:00:00 -0700
author: ryanmelt
version: 3.9.2
categories: [release]
---

### New Features:

* [#147](https://github.com/BallAerospace/COSMOS/issues/147) TlmExtractor Full Column Names Mode
* [#148](https://github.com/BallAerospace/COSMOS/issues/148) TlmExtractor Share individual columns
* [#189](https://github.com/BallAerospace/COSMOS/issues/189) ScriptRunner Breakpoints don't adapt to edits
* [#233](https://github.com/BallAerospace/COSMOS/issues/233) Add Config Option to Increase Tcpip Interface Timeout to TlmGrapher
* [#280](https://github.com/BallAerospace/COSMOS/issues/280) Method for determining interface packet count
* [#313](https://github.com/BallAerospace/COSMOS/issues/313) Add command line option to automatically start ScriptRunner
* [#336](https://github.com/BallAerospace/COSMOS/issues/336) Add Log Analyze Feature to TlmExtractor/CmdExtractor
* [#395](https://github.com/BallAerospace/COSMOS/issues/395) Implement Stylesheets Throughout
* [#408](https://github.com/BallAerospace/COSMOS/issues/408) Easy way to find which targets use an interface?
* [#433](https://github.com/BallAerospace/COSMOS/issues/433) Scripting support for TlmViewer close all screens
* [#434](https://github.com/BallAerospace/COSMOS/issues/434) TlmViewer option for no resize of screens
* [#436](https://github.com/BallAerospace/COSMOS/issues/436) PacketViewer option to ignore target.txt ignored items
* [#441](https://github.com/BallAerospace/COSMOS/issues/441) PacketViewer should identify derived items in the GUI

### Maintenance:

None

### Bug Fixes:

* [#417](https://github.com/BallAerospace/COSMOS/issues/417)  Table Manager not checking ranges
* [#419](https://github.com/BallAerospace/COSMOS/issues/419)  Support multiple arrays in string based commands

### Migration Notes from COSMOS 3.8.x:
**The Table Manager configuration file format has changed.**
Documentation will updated the first week of April.

You can migrate existing config files using:

```
bundle exec ruby tools\TableManager --convert config\tools\table_manager\old_table_def.txt
```

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
