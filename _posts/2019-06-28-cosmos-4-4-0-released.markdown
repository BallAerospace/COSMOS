---
layout: news_item
title: 'Ball Aerospace COSMOS 4.4.0 Released'
date: 2019-06-28 6:00:00 -0700
author: ryanmelt
version: 4.4.0
categories: [release]
---

Here's COSMOS 4.4.0!   52 tickets have been incorporated including 18 new features, 19 bug fixes and 15 general maintenance changes.

Overall this is just a stability bug fix release, but there are a few interesting changes.   For one, max packet reception speed has been greatly increased due to ticket #911.  CmdExtractor can now output in a CSV format. ScriptRunner has a recently opened file menu section, and the show_backtrace feature is now a menu option as well.  There is much better support for giving absolute paths to config files on the command line.  There is also a new LED type widget to display boolean telemetry.

Enjoy and see below for the full list of changes.

### Breaking Changes:

The faster identification in ticket #911 does come with a potentially breaking change.  The improvement requires that all packets for a given target be identified using the same fields (bit offset, bit_size, and type).   This is the typical configuration, and breaking this pattern is typically a dangerous/bad choice for interfaces anyways, but previously COSMOS did default to handling packets being potentially identified using different fields in the same target.  If you have a target that still requires that functionality, you need to declare CMD_UNIQUE_ID_MODE, and/or TLM_UNIQUE_ID_MODE in the target's target.txt file to indicate it should use the slower identification method.

### New Features:

* [#822](https://github.com/BallAerospace/COSMOS/issues/822) CmdExtractor CSV Output Option
* [#854](https://github.com/BallAerospace/COSMOS/issues/854) ScriptRunner open multiple files from File->Open
* [#877](https://github.com/BallAerospace/COSMOS/issues/877) Graph in PktViewer during Replay should open TlmGrapher in Replay
* [#878](https://github.com/BallAerospace/COSMOS/issues/878) Debugger enhancements
* [#886](https://github.com/BallAerospace/COSMOS/issues/886) Add show_backtrace menu option to ScriptRunner/TestRunner
* [#891](https://github.com/BallAerospace/COSMOS/issues/891) Ability for protocol write methods to write send commands to the interface that owns it
* [#893](https://github.com/BallAerospace/COSMOS/issues/893) Canvas image ease of use
* [#895](https://github.com/BallAerospace/COSMOS/issues/895) prompt should take color and font options
* [#911](https://github.com/BallAerospace/COSMOS/issues/911) Fast Identification
* [#918](https://github.com/BallAerospace/COSMOS/issues/918) Limits bar widget display specified range
* [#934](https://github.com/BallAerospace/COSMOS/issues/934) Recent Files list in Script Runner File menu
* [#938](https://github.com/BallAerospace/COSMOS/issues/938) Test Runner disable start buttons
* [#956](https://github.com/BallAerospace/COSMOS/issues/956) Templated Protocol Limited to One Target per Interface
* [#964](https://github.com/BallAerospace/COSMOS/issues/964) Improve error message when accessing packets during initialization
* [#986](https://github.com/BallAerospace/COSMOS/issues/986) Script Runner should note Disconnect mode in log
* [#987](https://github.com/BallAerospace/COSMOS/issues/987) Tools should support absolute paths on the command line
* [#990](https://github.com/BallAerospace/COSMOS/issues/990) Add Boolean Telemetry Widget
* [#1017](https://github.com/BallAerospace/COSMOS/issues/1017) Data Viewer component for colored text items

### Maintenance:

* [#880](https://github.com/BallAerospace/COSMOS/issues/880) tmp output not capitalizing targets
* [#884](https://github.com/BallAerospace/COSMOS/issues/884) Documentation updates
* [#913](https://github.com/BallAerospace/COSMOS/issues/913) Workaround Travis accept failures
* [#914](https://github.com/BallAerospace/COSMOS/issues/914) Increase json_drb start timeout
* [#925](https://github.com/BallAerospace/COSMOS/issues/925) Script syntax highlighting improvements
* [#930](https://github.com/BallAerospace/COSMOS/issues/930) Update COSMOS Travis builds
* [#940](https://github.com/BallAerospace/COSMOS/issues/940) Update keyword documentation
* [#953](https://github.com/BallAerospace/COSMOS/issues/953) Simplify Launcher.bat files
* [#955](https://github.com/BallAerospace/COSMOS/issues/955) Document tool command line options
* [#995](https://github.com/BallAerospace/COSMOS/issues/995) Test Runner should use LOAD_UTILITY to better match scripting
* [#998](https://github.com/BallAerospace/COSMOS/issues/998) Enable raw logging when LOG_RAW used
* [#1000](https://github.com/BallAerospace/COSMOS/issues/1000) Add IgnorePacketProtocol to defaults
* [#1005](https://github.com/BallAerospace/COSMOS/issues/1005) Celsius is misspelled
* [#1008](https://github.com/BallAerospace/COSMOS/issues/1008) Move handbook assets out of outputs
* [#1010](https://github.com/BallAerospace/COSMOS/issues/1010) Widget documentation and cleanup

### Bug Fixes:

* [#870](https://github.com/BallAerospace/COSMOS/issues/870) TlmViewer Block Widget exhibits weird scrolling issue
* [#874](https://github.com/BallAerospace/COSMOS/issues/874) Demo commanding screen can't run scripts
* [#882](https://github.com/BallAerospace/COSMOS/issues/882) Demo background task unable to be restarted
* [#889](https://github.com/BallAerospace/COSMOS/issues/889) FixedProtocol does not identify packets when leading bytes discarded
* [#908](https://github.com/BallAerospace/COSMOS/issues/908) Bad Hex String Conversion in Command Sender
* [#909](https://github.com/BallAerospace/COSMOS/issues/909) Replay doesn't work with TlmGrapher when loading saved_config
* [#916](https://github.com/BallAerospace/COSMOS/issues/916) Allow FORMAT_STRING before STATES
* [#919](https://github.com/BallAerospace/COSMOS/issues/919) Limits Checking Enabled Status on Properties Dialog not accurate
* [#920](https://github.com/BallAerospace/COSMOS/issues/920) Gemfile may be too strict in ruby-termios version requirement
* [#927](https://github.com/BallAerospace/COSMOS/issues/927) Error if DECLARE_TARGET with no SYSTEM target folder
* [#945](https://github.com/BallAerospace/COSMOS/issues/945) Screenshotting on Macs may not work
* [#948](https://github.com/BallAerospace/COSMOS/issues/948) Unable to connect limits monitor to replay server
* [#966](https://github.com/BallAerospace/COSMOS/issues/966) OpenGL Builder is Expecting "EarthMap1024x512.gif", but Packaged GIF is "Earthmap1024x512.gif"
* [#975](https://github.com/BallAerospace/COSMOS/issues/975) Multiple Errors in a chain of ScriptRunner Methods
* [#978](https://github.com/BallAerospace/COSMOS/issues/978) ScriptRunner breakpoints don't get set on the correct line
* [#980](https://github.com/BallAerospace/COSMOS/issues/980) Include target REQUIRE files in marshal
* [#983](https://github.com/BallAerospace/COSMOS/issues/983) Line number discrepancy in TestRunner Report/ScriptRunner output
* [#992](https://github.com/BallAerospace/COSMOS/issues/992) missing method in xtce_converter; process_xtce
* [#1022](https://github.com/BallAerospace/COSMOS/issues/1022) Table Manager TABLEFILE doesn't support subdirectories

### Migration Notes from COSMOS 4.3.0:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/