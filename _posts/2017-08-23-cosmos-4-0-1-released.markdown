---
layout: news_item
title: "Ball Aerospace COSMOS 4.0.1 Released"
date: 2017-08-23 12:00:00 -0700
author: ryanmelt
version: 4.0.1
categories: [release]
---

### New Features:

- [#527](https://github.com/BallAerospace/COSMOS/issues/527) Editing config files should now bring up ConfigEditor
- [#528](https://github.com/BallAerospace/COSMOS/issues/528) ConfigEditor missing some keywords
- [#534](https://github.com/BallAerospace/COSMOS/issues/534) Create ConfigEditor Mac app
- [#536](https://github.com/BallAerospace/COSMOS/issues/536) Clickable canvas objects open screens
- [#542](https://github.com/BallAerospace/COSMOS/issues/543) Automatically populate COMMAND SYSTEM META
- [#543](https://github.com/BallAerospace/COSMOS/issues/543) Allow SYSTEM META items to be read only

### Maintenance:

- None

### Bug Fixes:

- [#533](https://github.com/BallAerospace/COSMOS/issues/533) TestRunner strips all comments when running
- [#538](https://github.com/BallAerospace/COSMOS/issues/538) META_INIT broken
- [#540](https://github.com/BallAerospace/COSMOS/issues/540) Background task packet subscription get_packet broken
- [#547](https://github.com/BallAerospace/COSMOS/issues/547) convert_packet_to_data should copy buffer

### Migration Notes from COSMOS 3.8.x:

COSMOS 4 includes several breaking changes from the COSMOS 3.x series.

The first and simplest is that the Command and Telemetry Server now opens an additional port at 7780 by default, that provides a router that will send out each command that the system has sent. This can allow external systems to also log all commands sent by COSMOS. For most people this change will be transparent and no updates to your COSMOS configuration will be required.

The second is that the Command and Telemetry Server now always supports a meta data packet called SYSTEM META. This packet will always contain the MD5 sum for the current running COSMOS configuration, the version of COSMOS running, the version of your COSMOS Project, and the version of Ruby being used. You can also add your own requirements for meta data with things like the name of the operator currently running the system, or the name of a specific test you are currently running. In general you shouldn't need to do anything for this change unless you were using the previous metadata functionality in COSMOS. If you were, then you will need to migrate your meta data to the new SYSTEM META packet, and change the parameters in your CmdTlmServer or TestRunner configurations regarding meta data. If you weren't using metadata before, then you will probably just notice this new packet in your log files, and in your telemetry stream.

Finally the most exciting breaking change is in how COSMOS interfaces handle protocols. Before, the COSMOS TCP/IP and Serial interface classes each took a protocol like LENGTH, TERMINATED, etc that defined how packets were delineated by the interface. Now each interface can take a set of one or more protocols. This allows COSMOS to much more easily support nested protocols, such as the frame focused protocols of CCSDS. It also allows for creating helpful reusable protocols such as the new CRC protocol for automatically adding CRCs to outgoing commands and verifying incoming CRCs on telemetry packets. It's a great change, but if you have any custom interface classes you have written, they will probably require some modification. See the Interfaces section at cosmosc2.com to see how the new interface classes work. We will also be writing up a blog post to help document the process of upgrading. Look for this in a week or two.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
