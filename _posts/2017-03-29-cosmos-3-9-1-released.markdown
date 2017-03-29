---
layout: news_item
title: 'Ball Aerospace COSMOS 3.9.1 Released'
date: 2017-03-29 12:00:00 -0700
author: ryanmelt
version: 3.9.1
categories: [release]
---

### New Features:

* [#382](https://github.com/BallAerospace/COSMOS/issues/382) CmdTlmServer Start/Stop for background tasks
* [#385](https://github.com/BallAerospace/COSMOS/issues/385) Quick access to COSMOS gem code
* [#388](https://github.com/BallAerospace/COSMOS/issues/388) Legal Dialog should show COSMOS version
* [#409](https://github.com/BallAerospace/COSMOS/issues/409) Update LINC interface to support multiple targets on the same interface

### Maintenance:

* [#369](https://github.com/BallAerospace/COSMOS/issues/369) Table Manager refactoring
* [#386](https://github.com/BallAerospace/COSMOS/issues/386) Batch file for offline installation

### Bug Fixes:

* [#236](https://github.com/BallAerospace/COSMOS/issues/236) Test Runner doesn't support status_bar
* [#329](https://github.com/BallAerospace/COSMOS/issues/329) Using XTCE file instead of .txt cmd_tlm file didn't work as online docs suggest
* [#378](https://github.com/BallAerospace/COSMOS/issues/378) TlmViewer displaying partials in the screen list
* [#402](https://github.com/BallAerospace/COSMOS/issues/402) Mac installation is failed - Please help.
* [#411](https://github.com/BallAerospace/COSMOS/issues/411) xtce explicit byte order list processing isn't correct
* [#412](https://github.com/BallAerospace/COSMOS/issues/412) subscribe_packet_data needs to validate parameters

### Migration Notes from COSMOS 3.8.x:
**The Table Manager configuration file format has changed.**
Documentation will updated the first week of April.

You can migrate existing config files using:

```
bundle exec ruby tools\TableManager --convert config\tools\table_manager\old_table_def.txt
```

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
