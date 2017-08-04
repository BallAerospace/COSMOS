---
layout: news_item
title: 'Ball Aerospace COSMOS 4.0.0 Released'
date: 2017-08-04 12:00:00 -0700
author: ryanmelt
version: 4.0.0
categories: [release]
---

COSMOS 4 is here!

48 tickets have gone into this release, and it brings with it two new tools and some great under the hood improvements.

New Tools:

COSMOS now has a dedicated Configuration Editor and Command Sequence Builder.

The config editor gives you contextual help when building config files, and make it super easy to define packets and configure tools without having to have the online documentation up in front of you.  It's going to make setting up COSMOS even easier than it was before.

Command Sequence builder allows you to define series of commands that should be sent at either absolute or relative timestamps to each other.  This is great for planning time specific commanding.  You can execute these on the ground directly from the tool, or you can convert them to your own internal format and upload to the system you are commanding.

Highlighted changes:

1. New protocol system allows assigning multiple protocols to each interface to support layered protocols, and common functionality like CRC checking/adding to commands.
2. The ability to View the most recent raw data received or sent on each interface
3. The Command and Telemetry Server can now run on JRuby in --no-gui mode (may help performance for huge projects with 50+ targets)
4. New router provides the ability to get a copy of every command sent out from COSMOS in a stream
5. New SYSTEM META packet output by the CmdTlmServer
6. Lots more!  See the full ticket list below

### New Features:

* [#229](https://github.com/BallAerospace/COSMOS/issues/229)

* [#229](https://github.com/BallAerospace/COSMOS/issues/229) Gem Based Targets should support DataViewer and other tool configurations
* [#234](https://github.com/BallAerospace/COSMOS/issues/234) Add a method to system.txt to add files used in the marshall file MD5 sum calculation
* [#253](https://github.com/BallAerospace/COSMOS/issues/253) Create "generators" for targets, tools, etc
* [#258](https://github.com/BallAerospace/COSMOS/issues/258) Create COSMOS Command Sequence Tool
* [#261](https://github.com/BallAerospace/COSMOS/issues/261) Provide a method for specifying binary data in STRING and BLOCK default values
* [#278](https://github.com/BallAerospace/COSMOS/issues/278) Consider adding wait_ methods to internal API for use in Background tasks
* [#281](https://github.com/BallAerospace/COSMOS/issues/281) Add support for stretch and spacers in widget layouts
* [#319](https://github.com/BallAerospace/COSMOS/issues/319) Add the ability to grab telemetry ARRAY_ITEMs
* [#337](https://github.com/BallAerospace/COSMOS/issues/337) Support specifying default parameters to default log reader and log writer in system.txt
* [#347](https://github.com/BallAerospace/COSMOS/issues/347) COSMOS GLobal Time Zone Setting (Local/UTC)
* [#356](https://github.com/BallAerospace/COSMOS/issues/356) Interface protocols
* [#360](https://github.com/BallAerospace/COSMOS/issues/360) Add raw stream preamble and postamble data to "View Raw"
* [#381](https://github.com/BallAerospace/COSMOS/issues/381) Float Infinity and NaN as command values
* [#401](https://github.com/BallAerospace/COSMOS/issues/401) tolerance scripting calls should support array telemetry items
* [#404](https://github.com/BallAerospace/COSMOS/issues/404) Packet Viewer easy access to edit configuration files
* [#405](https://github.com/BallAerospace/COSMOS/issues/405) Telemetry Viewer easy access to edit screen definition
* [#423](https://github.com/BallAerospace/COSMOS/issues/423) Add "Cmd router" to CmdTlmServer to support external logging of all commands
* [#424](https://github.com/BallAerospace/COSMOS/issues/424) TlmViewer should call update_widget for a screen with no value items and with CmdTlmServer not running
* [#426](https://github.com/BallAerospace/COSMOS/issues/426) Standardize meta data to SYSTEM META packet
* [#432](https://github.com/BallAerospace/COSMOS/issues/432) Export processed config files
* [#442](https://github.com/BallAerospace/COSMOS/issues/442) Label value widgets should support right aligned labels
* [#459](https://github.com/BallAerospace/COSMOS/issues/459) Script Editor code completion enhancements
* [#479](https://github.com/BallAerospace/COSMOS/issues/479) Limits Monitor doesn't detect newly connected targets
* [#489](https://github.com/BallAerospace/COSMOS/issues/489) Built in support for limits group enable and disable
* [#497](https://github.com/BallAerospace/COSMOS/issues/497) Update serial_interface.rb to support hardware flow control
* [#498](https://github.com/BallAerospace/COSMOS/issues/498) Script helper for activities that should cause an exception
* [#511](https://github.com/BallAerospace/COSMOS/issues/511) Make CmdTlmServer run on JRuby
* [#512](https://github.com/BallAerospace/COSMOS/issues/512) Create a CRC Protocol
* [#513](https://github.com/BallAerospace/COSMOS/issues/513) Create a GUI config file editor
* [#516](https://github.com/BallAerospace/COSMOS/issues/516) Recreate COSMOS C Extension Code in Pure Ruby
* [#517](https://github.com/BallAerospace/COSMOS/issues/517) Make hostname for tools to connect to CTS API configurable in system.txt
* [#519](https://github.com/BallAerospace/COSMOS/issues/519) Replay should support alternate packet log readers

### Maintenance:

* [#354](https://github.com/BallAerospace/COSMOS/issues/354) Targets need to be path namespaced to avoid conflicts
* [#323](https://github.com/BallAerospace/COSMOS/issues/323) Catch Signals in CmdTlmServer
* [#341](https://github.com/BallAerospace/COSMOS/issues/341) Document COSMOS JSON API on cosmosrb.com
* [#398](https://github.com/BallAerospace/COSMOS/issues/398) Documentation, code cleanup
* [#429](https://github.com/BallAerospace/COSMOS/issues/429) Command Endianness and Parameter Endianness
* [#437](https://github.com/BallAerospace/COSMOS/issues/437) Remove CMD_TLM_VERSION from system.txt
* [#438](https://github.com/BallAerospace/COSMOS/issues/438) Cache script text as part of instrumenting script
* [#446](https://github.com/BallAerospace/COSMOS/issues/446) Windows 10 Install fails
* [#476](https://github.com/BallAerospace/COSMOS/issues/476) Separate apt and yum package install lines
* [#477](https://github.com/BallAerospace/COSMOS/issues/477) Deprecate userpath.txt
* [#484](https://github.com/BallAerospace/COSMOS/issues/484) require_file should re-raise existing exception

### Bug Fixes:

* [#456](https://github.com/BallAerospace/COSMOS/issues/456) Replay doesn't shut down properly if closed while playing
* [#481](https://github.com/BallAerospace/COSMOS/issues/481) show_backtrace not working in ScriptRunner
* [#494](https://github.com/BallAerospace/COSMOS/issues/494) Details dialog crashes for items with LATEST packet
* [#502](https://github.com/BallAerospace/COSMOS/issues/502) Target REQUIRE should also search system path
* [#506](https://github.com/BallAerospace/COSMOS/issues/506) Don't call read_interface if data is cached in protocols for another packet

### Migration Notes from COSMOS 3.8.x:

COSMOS 4 includes several breaking changes from the COSMOS 3.x series.

The first and simplest is that the Command and Telemetry Server now opens an additional port at 7780 by default, that provides a router that will send out each command that the system has sent.  This can allow external systems to also log all commands sent by COSMOS.  For most people this change will be transparent and no updates to your COSMOS configuration will be required.

The second is that the Command and Telemetry Server now always supports a meta data packet called SYSTEM META.  This packet will always contain the MD5 sum for the current running COSMOS configuration, the version of COSMOS running, the version of your COSMOS Project, and the version of Ruby being used.  You can also add your own requirements for meta data with things like the name of the operator currently running the system, or the name of a specific test you are currently running.  In general you shouldn't need to do anything for this change unless you were using the previous metadata functionality in COSMOS.  If you were, then you will need to migrate your meta data to the new SYSTEM META packet, and change the parameters in your CmdTlmServer or TestRunner configurations regarding meta data.  If you weren't using metadata before, then you will probably just notice this new packet in your log files, and in your telemetry stream.

Finally the most exciting breaking change is in how COSMOS interfaces handle protocols.  Before, the COSMOS TCP/IP and Serial interface classes each took a protocol like LENGTH, TERMINATED, etc that defined how packets were delineated by the interface.  Now each interface can take a set of one or more protocols.  This allows COSMOS to much more easily support nested protocols, such as the frame focused protocols of CCSDS.  It also allows for creating helpful reusable protocols such as the new CRC protocol for automatically adding CRCs to outgoing commands and verifying incoming CRCs on telemetry packets.  It's a great change, but if you have any custom interface classes you have written, they will probably require some modification.  See the Interfaces section at cosmosrb.com to see how the new interface classes work. We will also be writing up a blog post to help document the process of upgrading.  Look for this in a week or two.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.
