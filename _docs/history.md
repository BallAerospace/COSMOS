---
layout: docs
title: Release History
permalink: "/docs/history/"
---

## 3.4.2 / 2015-05-08
{: #v3-4-2}

### Issues:

* [#123](https://github.com/BallAerospace/COSMOS/issues/123) TestRunner command line option to launch a test automatically
* [#125](https://github.com/BallAerospace/COSMOS/issues/125) Fix COSMOS issues for qtbindings 4.8.6.2
* [#126](https://github.com/BallAerospace/COSMOS/issues/126) COSMOS GUI Chooser updates

### Migration Notes from COSMOS 3.3.x or 3.4.x:

COSMOS 3.4.2 requires qtbindings 4.8.6.2. You must also update qtbindings when installing this release. Also note that earlier versions of COSMOS will not work with qtbindings 4.8.6.2. All users are strongly recommended to update both gems.

## 3.4.1 / 2015-05-01
{: #v3-4-1}

### Issues:

* [#121](https://github.com/BallAerospace/COSMOS/issues/121) BinaryAccessor write crashes with negative bit sizes

### Migration Notes from COSMOS 3.3.x:

None

Note: COSMOS 3.4.0 has a serious regression when writing to variably sized packets. Please upgrade to 3.4.1 immediately if you are using 3.4.0.


## 3.4.0 / 2015-04-27
{: #v3-4-0}

### Issues:

* [#23](https://github.com/BallAerospace/COSMOS/issues/23) Handbook Creator User's Guide Mode
* [#72](https://github.com/BallAerospace/COSMOS/issues/72) Refactor binary_accessor
* [#101](https://github.com/BallAerospace/COSMOS/issues/101) Support Ruby 2.2 and 64-bit Ruby on Windows
* [#104](https://github.com/BallAerospace/COSMOS/issues/104) CmdTlmServer Loading Tmp & SVN Conflict Files
* [#107](https://github.com/BallAerospace/COSMOS/issues/107) Remove truthy and falsey from specs
* [#110](https://github.com/BallAerospace/COSMOS/issues/110) Optimize TlmGrapher
* [#111](https://github.com/BallAerospace/COSMOS/issues/111) Protect Interface Thread Stop from AutoReconnect
* [#114](https://github.com/BallAerospace/COSMOS/issues/114) Refactor Cosmos::Script module
* [#118](https://github.com/BallAerospace/COSMOS/issues/118) Allow PacketViewer to hide ignored items

### Migration Notes from COSMOS 3.3.x:

None

## 3.3.3 / 2015-03-23
{: #v3-3-3}

### Issues:

* [#93](https://github.com/BallAerospace/COSMOS/issues/93) Derived items that return arrays are not formatted to strings bug
* [#94](https://github.com/BallAerospace/COSMOS/issues/94) JsonDRb retry if first attempt hits a closed socket bug
* [#96](https://github.com/BallAerospace/COSMOS/issues/96) Make max lines written to output a variable in ScriptRunnerFrame enhancement
* [#99](https://github.com/BallAerospace/COSMOS/issues/99) Increase Block Count in DataViewer

### Migration Notes from COSMOS 3.2.x:

System.telemetry.target_names and System.commands.target_names no longer contain the 'UNKNOWN' target.

## 3.3.1 / 2015-03-19
{: #v3-3-1}

COSMOS first-time startup speed is now 16 times faster - hence this release is codenamed "Startup Cheetah". Enjoy!

### Issues:

* [#91](https://github.com/BallAerospace/COSMOS/issues/91) Add mutex around creation of System.instance
* [#89](https://github.com/BallAerospace/COSMOS/issues/89) Reduce maximum block count from 10000 to 100 everywhere
* [#87](https://github.com/BallAerospace/COSMOS/issues/87) MACRO doesn't support more than one item
* [#85](https://github.com/BallAerospace/COSMOS/issues/85) Replace use of DL with Fiddle
* [#82](https://github.com/BallAerospace/COSMOS/issues/82) Improve COSMOS startup speed
* [#81](https://github.com/BallAerospace/COSMOS/issues/81) UNKNOWN target identifies all buffers before other targets have a chance
* [#78](https://github.com/BallAerospace/COSMOS/issues/78) Reduce COSMOS memory usage
* [#76](https://github.com/BallAerospace/COSMOS/issues/76) Fix specs to new expect syntax and remove 'should'
* [#74](https://github.com/BallAerospace/COSMOS/issues/74) Server requests/sec and utilization are incorrect

### Migration Notes from COSMOS 3.2.x:

System.telemetry.target_names and System.commands.target_names no longer contain the 'UNKNOWN' target.

## 3.2.1 / 2015-02-23
{: #v3-2-1}

### Issues:

* [#61](https://github.com/BallAerospace/COSMOS/issues/61) Don't crash TestRunner if there is an error during require_utilities()
* [#63](https://github.com/BallAerospace/COSMOS/issues/63) Creating interfaces with the same name does not cause an error
* [#64](https://github.com/BallAerospace/COSMOS/issues/64) Launcher RUBYW substitution broken by refactor
* [#65](https://github.com/BallAerospace/COSMOS/issues/65) CmdTlmServer ensure log messages start scrolled to bottom on Linux
* [#66](https://github.com/BallAerospace/COSMOS/issues/66) Improve graceful shutdown on linux and prevent continuous exceptions from InterfaceThread
* [#70](https://github.com/BallAerospace/COSMOS/issues/70) ask() should take a default

### Migration Notes from COSMOS 3.1.x:

No significant updates to existing code should be needed. The primary reason for update to 3.2.x is fixing the slow shutdown present in all of 3.1.x.

## 3.2.0 / 2015-02-17
{: #v3-2-0}

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

## 3.1.2 / 2015-02-03
{: #v3-1-2}

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

## 3.1.1 / 2015-01-28
{: #v3-1-1}

### Issues:

 * [#10](https://github.com/BallAerospace/COSMOS/issues/10) Simulated Targets Button only works on Windows
 * [#11](https://github.com/BallAerospace/COSMOS/issues/11) Mac application folders not working
 * [#12](https://github.com/BallAerospace/COSMOS/issues/12) Persistence should be applied even if changing from stale
 * [#14](https://github.com/BallAerospace/COSMOS/issues/14) Allow information on logging page to be copied
 * [#16](https://github.com/BallAerospace/COSMOS/issues/16) Ensure read conversion cache cannot be cleared mid-use
 * [#17](https://github.com/BallAerospace/COSMOS/issues/17) NaNs in telemetry graph causes scaling crash

### Migration Notes from COSMOS 3.0.x:

The definition of limits persistence has changed. Before it only applied when changing to a bad state (yellow or red). Now persistence applies for all changes including from stale to a valid state and from bad states back to green.

## 3.0.1 / 2015-01-06
{: #v3-0-1}

First Announced Open Source Release
