---
layout: docs
title: Release History
permalink: "/docs/history/"
---

## 4.5.0 / 2020-11-05
{: #v4-5-0}

COSMOS 4.5 - 

This is a security and bug fix release.  All users are recommended to update. Please see the migration notes below for necessary changes when upgrading from 4.4.2.

### Security Updates:

* [#672](https://github.com/BallAerospace/COSMOS/issues/672) Secure COSMOS API with Shared Secret
* [#1227](https://github.com/BallAerospace/COSMOS/issues/1227) Prevent a Malicious Website From Sending Commands

### Bug Fixes:

* [#1135](https://github.com/BallAerospace/COSMOS/issues/1135) Command Sequence Tool Overriding String Parameter
* [#1151](https://github.com/BallAerospace/COSMOS/issues/1151) CmdSender not setting description
* [#1158](https://github.com/BallAerospace/COSMOS/issues/1158) Loss of 1 us precision on CCSDS time when using Time.ccsds2sec method
* [#1164](https://github.com/BallAerospace/COSMOS/issues/1164) CmdTlmServer#reload always uses default system.txt
* [#1167](https://github.com/BallAerospace/COSMOS/issues/1167) Serial Driver Initialization Bug
* [#1196](https://github.com/BallAerospace/COSMOS/issues/1196) COSMOS windows stuck offscreen at Startup
* [#1200](https://github.com/BallAerospace/COSMOS/issues/1200) Handbook PDF Generation wkhtmltopdf ProtocolUnknownError
* [#1210](https://github.com/BallAerospace/COSMOS/issues/1210) Move CheckError definition to ApiShared

### New Features:

* [#1141](https://github.com/BallAerospace/COSMOS/issues/1141) Enable setting arbitrary bits in the serial drivers


### Maintenance:
* [#1136](https://github.com/BallAerospace/COSMOS/issues/1136) Telemetry Extractor delimiter on last item

### Migration Notes from COSMOS 4.4,x:
To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

Modify you system.txt files to:

1. Make sure you have a X_CSRF_TOKEN line with a unique value (anything will do, just change it)
2. Change all LISTEN_HOST settings to 127.0.01 unless you need connections from external hosts
3. If you know only specific external hosts will be connecting, add ALLOW_ACCESS lines for each
4. Only add ALLOW_ROUTER_COMMANDING if you are chaining CmdTlmServers (that need to send commands), or you are receiving commands through routers
5. Only add ALLOW_ORIGIN <Address of webpage>if you expect COSMOS to be accessed from a webpage
6. Add ALLOW_HOST <Your COSMOS IP Address>:7777, etc if you expect the COSMOS APIs to be accessed from external computers.  Otherwise it will only accept connections that have a HOST header set to localhost

## 5.0.0-alpha.1 / 2020-08-31
{: #v5-0-0-alpha-1}

I am proud to announce the release of COSMOS 5 Alpha 1!  

COSMOS 5 is a highly scalable, cloud native, command and control software system.  This is a technology preview release meant to introduce all of the new technologies debuting in COSMOS 5. 

New Technologies:

* Docker - COSMOS 5 runs across a set of containers managed by Docker
* Redis - Redis is used as a key-value store, and streaming data server
* Minio - Minio provides an S3 compatible file storage server
* EFK Stack - Elasticsearch, Fluentd, Kibana - Provide a distributed logging solution
* Vue.js - Javascript technology used to build the new COSMOS user interface

Basic versions of the following COSMOS tools are included in this release:

* Command and Telemetry Server
* Command Sender
* Packet Viewer
* Telemetry Viewer
* Telemetry Grapher
* Script Runner
* Limits Monitor

### Prerequisites:

* Docker - Running COSMOS 5 requires a working Docker installation.  Typically Docker Desktop on Windows / Mac.  Plain docker should work on linux.  We're currently only developing / running with Docker Desktop on Windows, so if you have any issues on another platform, please let us know by submitting a ticket!

Minimum Resources allocated to Docker: 4GB RAM, 1 CPU, 60GB Disk
Recommended Resources allocated to Docker: 8GB RAM, 2+ CPUs, 100GB Disk

### To Run:

1. Download one of the archives (.zip or .tar.gz from the Github release page) [Download Release Here](https://github.com/BallAerospace/COSMOS/releases/tag/v5.0.0-alpha.1)
2. Extract the archive somewhere on your host computer
3. The COSMOS 5 containers are designed to work and be built in the presence of an SSL Decryption device.  To support this a cacert.pem file can be placed at the base of the COSMOS 5 project that includes any certificates needed by your organization.  If you don't need this, then please ignore, but if you see any SSL errors, this is probably why.
4. Run cosmos_start.bat (Windows), or cosmos_start.sh (linux/Mac)
5. COSMOS 5 will be built and when ready should be running (~15 mins for first run, ~2 for subsequent)
6. Connect a web browser to http://localhost:8080
7. Have fun trying out COSMOS 5!

Please try it out and let us know what you think!  Please submit any issues as Github tickets, or any generic feedback to COSMOS@ball.com.  

Note that this release is not ready for production use.  We will have a more beta ready release in a few months.

Thanks!

## 4.4.2 / 2020-03-09
{: #v4-4-2}

COSMOS 4.4.2!   A minor bug fix release.

Enjoy and see below for the full list of changes.

### New Features:

None

### Maintenance:
* [#1117](https://github.com/BallAerospace/COSMOS/issues/1117) Include name in TcpipServerInteface log messages
* [#1128](https://github.com/BallAerospace/COSMOS/issues/1128) wkhtmltopdf has old comment

### Bug Fixes:

* [#1126](https://github.com/BallAerospace/COSMOS/issues/1126) Packets with identically named items fail checks

### Migration Notes from COSMOS 4.3.0:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

The faster identification in ticket #911 does come with a potentially breaking change.  The improvement requires that all packets for a given target be identified using the same fields (bit offset, bit_size, and type).   This is the typical configuration, and breaking this pattern is typically a dangerous/bad choice for interfaces anyways, but previously COSMOS did default to handling packets being potentially identified using different fields in the same target.  If you have a target that still requires that functionality, you need to declare CMD_UNIQUE_ID_MODE, and/or TLM_UNIQUE_ID_MODE in the target's target.txt file to indicate it should use the slower identification method.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/


## 4.4.1 / 2019-12-30
{: #v4-4-1}

Onward to COSMOS 4.4.1!   27 tickets have been incorporated including 6 new features, 13 bug fixes and 8 general maintenance changes.

Mainly a stability bug fix release, but there are a few cool changes.  There is an new keyword for marking that bit overlaps are intentional in packet definition files.  This can get rid of those annoying warnings when you do this intentionally.  There is also a new DELETE_ITEM keyword to get rid of items potentially added by auto generation.   Tlm Extractor and Tlm Grapher can now pull more than 10,000 data points from DART.   Also, there is now the ability to package multiple targets into one gem. 

Enjoy and see below for the full list of changes.

### New Features:

* [#817](https://github.com/BallAerospace/COSMOS/issues/817) Allow for intentional bit overlaps in definition
* [#821](https://github.com/BallAerospace/COSMOS/issues/821) Support DART queries larger than 10000 samples in TlmExtractor / TlmGrapher
* [#922](https://github.com/BallAerospace/COSMOS/issues/922) DELETE_ITEM
* [#1028](https://github.com/BallAerospace/COSMOS/issues/1028) Support Multiple Targets Packaged into Single Gem
* [#1040](https://github.com/BallAerospace/COSMOS/issues/1040) Config Editor new system config wizard
* [#1104](https://github.com/BallAerospace/COSMOS/issues/1104) Create releases from Docker

### Maintenance:

* [#1016](https://github.com/BallAerospace/COSMOS/issues/1016) Make JSON RPC API Command Methods Case Insensitive
* [#1030](https://github.com/BallAerospace/COSMOS/issues/1030) Scrolling in config editor can cause issues
* [#1039](https://github.com/BallAerospace/COSMOS/issues/1039) Config Editor performance enhancements
* [#1056](https://github.com/BallAerospace/COSMOS/issues/1056) AppVeyer broken
* [#1074](https://github.com/BallAerospace/COSMOS/issues/1074) For BLOCK parameters, suggest 0x0 as default value
* [#1080](https://github.com/BallAerospace/COSMOS/issues/1080) DART stream server docs
* [#1090](https://github.com/BallAerospace/COSMOS/issues/1090) DART Reduction unreliable with file imported data
* [#1101](https://github.com/BallAerospace/COSMOS/issues/1101) Windows 10 Install Error?

### Bug Fixes:

* [#883](https://github.com/BallAerospace/COSMOS/issues/883) DART meta filter not populating
* [#944](https://github.com/BallAerospace/COSMOS/issues/944) DART data retrievals not per packet_time
* [#1012](https://github.com/BallAerospace/COSMOS/issues/1012) Screens can't call display when launched with --screen
* [#1031](https://github.com/BallAerospace/COSMOS/issues/1031) Graphing a telemetry member whose name includes brackets fails
* [#1036](https://github.com/BallAerospace/COSMOS/issues/1036) TestRunner: ABORT_TESTING_AFTER_ERROR ignored for test cases added indivually to testsuite
* [#1037](https://github.com/BallAerospace/COSMOS/issues/1037) telemetry#all_item_strings support undeclared target names
* [#1051](https://github.com/BallAerospace/COSMOS/issues/1051) Windows serial port hangs on write
* [#1061](https://github.com/BallAerospace/COSMOS/issues/1061) Excel can't open a blank worksheet
* [#1063](https://github.com/BallAerospace/COSMOS/issues/1063) Length Protocol does not handle 0 length
* [#1064](https://github.com/BallAerospace/COSMOS/issues/1064) Command Sequence Repeating Write_Conversion
* [#1081](https://github.com/BallAerospace/COSMOS/issues/1081) Ruby Syntax Error Checker Hangs Test Runner
* [#1087](https://github.com/BallAerospace/COSMOS/issues/1087) COSMOS Installation failure in building puma_http11
* [#1092](https://github.com/BallAerospace/COSMOS/issues/1092) Typo in Odd Parity

### Migration Notes from COSMOS 4.3.0:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

The faster identification in ticket #911 does come with a potentially breaking change.  The improvement requires that all packets for a given target be identified using the same fields (bit offset, bit_size, and type).   This is the typical configuration, and breaking this pattern is typically a dangerous/bad choice for interfaces anyways, but previously COSMOS did default to handling packets being potentially identified using different fields in the same target.  If you have a target that still requires that functionality, you need to declare CMD_UNIQUE_ID_MODE, and/or TLM_UNIQUE_ID_MODE in the target's target.txt file to indicate it should use the slower identification method.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/


## 4.4.0 / 2019-06-28
{: #v4-4-0}

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

## 4.3.0 / 2018-08-30
{: #v4-3-0}

Welcome to COSMOS 4.3.0!   

The highlight of this release is built in support for differentiating between stored telemetry and realtime telemetry.  If your system downlinks stored telemetry that you don't want to interfere with the COSMOS realtime current value table, your interface/protocol code can set the stored flag on a packet before returning it to COSMOS to have COSMOS log the packet, but not update the current telemetry values.     

Lots of other new features as well, and a few bug fixes including fixing running on the latest version of Mac OSX.  See below for the full list.

Breaking Changes:
The COSMOS log file format and predentified protocol formats have changed to support stored telemetry.   COSMOS 4.3 is backwards compatible with earlier formats, but older versions of COSMOS won't be able to read files from COSMOS 4.3+.

### New Features:

* [#780](https://github.com/BallAerospace/COSMOS/issues/780) Search bar support for Command Sequence
* [#785](https://github.com/BallAerospace/COSMOS/issues/785) Adjust font size
* [#804](https://github.com/BallAerospace/COSMOS/issues/804) Add classification bar to all tools
* [#808](https://github.com/BallAerospace/COSMOS/issues/808) Add CANVASELLIPSE widget
* [#814](https://github.com/BallAerospace/COSMOS/issues/814) Changes to support stored telemetry
* [#815](https://github.com/BallAerospace/COSMOS/issues/815) Create a temporary screen from a script
* [#818](https://github.com/BallAerospace/COSMOS/issues/818) Catch all state for any undefined state values
* [#819](https://github.com/BallAerospace/COSMOS/issues/819) Ensure x values added in incrementing order in TlmGrapher
* [#823](https://github.com/BallAerospace/COSMOS/issues/823) Add protocol to ignore any packet
* [#826](https://github.com/BallAerospace/COSMOS/issues/826) Allow hash style access to Excel
* [#829](https://github.com/BallAerospace/COSMOS/issues/829) Add STAY_ON_TOP feature to telemetry screens
* [#851](https://github.com/BallAerospace/COSMOS/issues/851) Ensure step_mode displays Step button
* [#859](https://github.com/BallAerospace/COSMOS/issues/859) Change Script Runner highlight color when paused

### Maintenance:

* [#796](https://github.com/BallAerospace/COSMOS/issues/796) Handle Command Sequence Export Issues
* [#807](https://github.com/BallAerospace/COSMOS/issues/807) Revert Items with STATE cannot define FORMAT_STRING
* [#812](https://github.com/BallAerospace/COSMOS/issues/812) Ruby 2.5 Instrumented Code outside of methods in a class
* [#855](https://github.com/BallAerospace/COSMOS/issues/855) Remove Qt warning message on Windows 10
* [#858](https://github.com/BallAerospace/COSMOS/issues/858) Fix JRuby build issues

### Bug Fixes:

* [#837](https://github.com/BallAerospace/COSMOS/issues/837) Packet Viewer's "Hide Ignored Items" Incorrectly Persists Across Change of Packet
* [#840](https://github.com/BallAerospace/COSMOS/issues/840) Latest version of COSMOS crashing
* [#845](https://github.com/BallAerospace/COSMOS/issues/845) Support get_tlm_details in disconnect mode

### Migration Notes from COSMOS 4.2.x:
To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

## 4.2.4 / 2018-05-16
{: #v4-2-4}

This is the second patch release for 4.2.  It greatly improves the ingest speed for DART (100x), improves decom speed, reduces database size, and fixes some bugs.  If you are using DART, please upgrade and follow the migration directions at the end of these release notes.

The highlight of COSMOS 4.2 is a new tool called the Data Archival and Retrieval Tool (DART).   DART is a long term trending database built on top of the PostgreSql database.  It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range.  Queries are super fast and it performs automatic data reduction at minute/hour/day granularity.  Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

### New Features:

* [#787](https://github.com/BallAerospace/COSMOS/issues/787) No way to control data bits on serial interface
* [#788](https://github.com/BallAerospace/COSMOS/issues/788) ROUTERS should support PROTOCOL keyword

### Maintenance:

* [#784](https://github.com/BallAerospace/COSMOS/issues/784) Comparable and spaceship operator behavior changing
* [#791](https://github.com/BallAerospace/COSMOS/issues/791) Table Manager doesn't expose top level layout

### Bug Fixes:

* [#779](https://github.com/BallAerospace/COSMOS/issues/779) Dart updates for ingest speed, correct time zone, TlmGrapher crash
* [#786](https://github.com/BallAerospace/COSMOS/issues/786) Status tab crash on Ruby 2.5
* [#790](https://github.com/BallAerospace/COSMOS/issues/790) Telemetry check doesn't support strings with multiple spaces

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

If you already setup DART for your program please follow the following additional steps:
In a terminal in your COSMOS project folder run:

```
rake db:migrate
rake db:seed
```

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

## 4.2.3 / 2018-04-17
{: #v4-2-3}

COSMOS 4.2 is here!   This is the first true patch release for 4.2.  The highlight of COSMOS 4.2 is a new tool called the Data Archival and Retrieval Tool (DART).   DART is a long term trending database built on top of the PostgreSql database.  It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range.  Queries are super fast and it performs automatic data reduction at minute/hour/day granularity.  Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

### New Features:

* [#767](https://github.com/BallAerospace/COSMOS/issues/767) Support Ruby 2.5
* [#771](https://github.com/BallAerospace/COSMOS/issues/771) Add CmdSender Search

### Maintenance:

* [#772](https://github.com/BallAerospace/COSMOS/issues/772) OpenGL gem isn't supported in Ruby 2.5

### Bug Fixes:

* [#769](https://github.com/BallAerospace/COSMOS/issues/769) TIMEGRAPH widget non-functional
* [#775](https://github.com/BallAerospace/COSMOS/issues/775) Toggle disconnect broken in TestRunner

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

## 4.2.2 / 2018-04-11
{: #v4-2-2}

COSMOS 4.2 is here!   Thirty four tickets went into this release, but the highlight is a new tool called the Data Archival and Retrieval Tool (DART).   DART is a long term trending database built on top of the PostgreSql database.  It integrates directly with TlmGrapher, TlmExtractor, CmdExtractor, DataViewer, and Replay, allowing you to do historical queries of logged telemetry (and commands) by specifying a time range.  Queries are super fast and it performs automatic data reduction at minute/hour/day granularity.  Consider setting it up for your project and start data mining today!

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/

### New Features:

* [#698](https://github.com/BallAerospace/COSMOS/issues/698) Initial DART Release
* [#650](https://github.com/BallAerospace/COSMOS/issues/650) Gracefully handle large array items
* [#673](https://github.com/BallAerospace/COSMOS/issues/673) Button widget should spawn thread to avoid blocking GUI
* [#676](https://github.com/BallAerospace/COSMOS/issues/676) Allow individual interfaces to be disconnect mode
* [#699](https://github.com/BallAerospace/COSMOS/issues/699) Test cases added to TestRunner should be ordered in drop down
* [#705](https://github.com/BallAerospace/COSMOS/issues/705) Cmd line arg for ScriptRunner to start in disconnect mode
* [#706](https://github.com/BallAerospace/COSMOS/issues/706) Warn if ITEMs or PARAMETERs are redefined
* [#711](https://github.com/BallAerospace/COSMOS/issues/711) Allow ERB to know the target name
* [#715](https://github.com/BallAerospace/COSMOS/issues/715) Allow individual Limits Monitor items to be removed (not ignored)
* [#719](https://github.com/BallAerospace/COSMOS/issues/719) Warn if limits_group doesn't exist in limits_groups_background_task
* [#729](https://github.com/BallAerospace/COSMOS/issues/729) CmdSender production mode to disable MANUALLY ENTERED
* [#734](https://github.com/BallAerospace/COSMOS/issues/734) Support DERIVED with APPEND
* [#737](https://github.com/BallAerospace/COSMOS/issues/737) Implement single stepping with the F10 key
* [#754](https://github.com/BallAerospace/COSMOS/issues/754) Add Replay Mode to Include All Routers
* [#765](https://github.com/BallAerospace/COSMOS/issues/765) TlmGrapher sampled analysis

### Maintenance:

* [#682](https://github.com/BallAerospace/COSMOS/issues/682) Fix Ruby interpreter warnings
* [#687](https://github.com/BallAerospace/COSMOS/issues/687) Add ConfigEditor AHK tests
* [#688](https://github.com/BallAerospace/COSMOS/issues/688) Windows 10 Installation Error - RDoc parsing failure in qtruby4.rb
* [#692](https://github.com/BallAerospace/COSMOS/issues/692) Fix METADATA usage in demo
* [#738](https://github.com/BallAerospace/COSMOS/issues/738) PacketViewer scroll to item on search
* [#748](https://github.com/BallAerospace/COSMOS/issues/748) Syntax highlighting prioritizes string over comment
* [#750](https://github.com/BallAerospace/COSMOS/issues/750) TestRunner hides syntax errors with broad rescue
* [#752](https://github.com/BallAerospace/COSMOS/issues/752) Demo INST commanding screen broken
* [#757](https://github.com/BallAerospace/COSMOS/issues/757) Increase TlmGrapher timeout to better support Replay
* [#759](https://github.com/BallAerospace/COSMOS/issues/759) Allow underscores and dashes in log filename labels

### Bug Fixes:

* [#690](https://github.com/BallAerospace/COSMOS/issues/690) Automatic SYSTEM META definition doesn't include RECEIVED_XX
* [#691](https://github.com/BallAerospace/COSMOS/issues/691) tools/mac apps won't open
* [#701](https://github.com/BallAerospace/COSMOS/issues/701) XTCE String types should not have ByteOrderList
* [#709](https://github.com/BallAerospace/COSMOS/issues/709) Can't set breakpoint in subscript
* [#713](https://github.com/BallAerospace/COSMOS/issues/713) Launcher crashes if newline in crc.txt
* [#723](https://github.com/BallAerospace/COSMOS/issues/723) crc_protocol needs better input validation
* [#727](https://github.com/BallAerospace/COSMOS/issues/727) Install issue on Windows 10
* [#732](https://github.com/BallAerospace/COSMOS/issues/732) losing/gaining data when routing at different incoming rates
* [#735](https://github.com/BallAerospace/COSMOS/issues/735) Statistics Processor doesn't handle nil or infinite
* [#740](https://github.com/BallAerospace/COSMOS/issues/740) About dialog crashes if USER_VERSION not defined

### Migration Notes from COSMOS 4.1.x:

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

See the COSMOS documentation for directions on setting up DART: http://cosmosrb.com/docs/home/


## 4.1.1 / 2017-12-07
{: #v4-1-1}

### New Features:

* [#663](https://github.com/BallAerospace/COSMOS/issues/663) Built-in protocols to support allow_empty_data
* [#666](https://github.com/BallAerospace/COSMOS/issues/666) Add ability to create target in ConfigEditor
* [#679](https://github.com/BallAerospace/COSMOS/issues/679) TlmViewer screen audit shouldn't count reserved item names

### Maintenance:

* [#660](https://github.com/BallAerospace/COSMOS/issues/660) Update Opengl gem requirement version
* [#665](https://github.com/BallAerospace/COSMOS/issues/665) Refactor xtce parser

### Bug Fixes:

* [#661](https://github.com/BallAerospace/COSMOS/issues/661) Render function bug?
* [#674](https://github.com/BallAerospace/COSMOS/issues/674) Add TlmViewerConfig spec and fix to_save

### Migration Notes from COSMOS 4.0.x:

Any custom tools in other languages that use the COSMOS API will need to be updated.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

## 4.1.0 / 2017-11-17
{: #v4-1-0}

Welcome to COSMOS 4.1!  The COSMOS API has transitioned from a custom TCP protocol to HTTP.  This will make interfacing to COSMOS from programming languages other than Ruby much easier.  There are also many new APIs that allows the full functionality of the CmdTlmServer and Replay to be controlled remotely.  See below for the full list of changes!

### New Features:

* [#531](https://github.com/BallAerospace/COSMOS/issues/531) Command sequence export option
* [#558](https://github.com/BallAerospace/COSMOS/issues/558) subscription APIs should work in disconnect mode
* [#559](https://github.com/BallAerospace/COSMOS/issues/559) Build Replay Functionality into CmdTlmServer
* [#578](https://github.com/BallAerospace/COSMOS/issues/578) Add ability to query available screens from Telemetry Viewer
* [#579](https://github.com/BallAerospace/COSMOS/issues/579) Create zip of configuration in saved config
* [#581](https://github.com/BallAerospace/COSMOS/issues/581) Make various log files readonly
* [#587](https://github.com/BallAerospace/COSMOS/issues/587) AUTO_INTERFACE_TARGETS ignore existing interfaces
* [#591](https://github.com/BallAerospace/COSMOS/issues/591) Investigate creating single COSMOS UDP socket for case where read_port == write_src_port
* [#599](https://github.com/BallAerospace/COSMOS/issues/599) Create subscription API for CTS messages
* [#601](https://github.com/BallAerospace/COSMOS/issues/601) Add background task and other status APIs
* [#606](https://github.com/BallAerospace/COSMOS/issues/606) Enhancement to Open File Script Interface - File Filter
* [#612](https://github.com/BallAerospace/COSMOS/issues/612) CSV support for strings and symbols
* [#620](https://github.com/BallAerospace/COSMOS/issues/620) Move Script Runner step button next to start/go
* [#625](https://github.com/BallAerospace/COSMOS/issues/625) Add APIs to start/stop background tasks
* [#626](https://github.com/BallAerospace/COSMOS/issues/626) Add API functions to get ignored parameters/items
* [#635](https://github.com/BallAerospace/COSMOS/issues/635) get_cmd_param_list should return the type for each command parameter
* [#642](https://github.com/BallAerospace/COSMOS/issues/642) Handle Infinity/NaN without invalid JSON

### Maintenance:

* [#510](https://github.com/BallAerospace/COSMOS/issues/510) Investigate changing JsonDrb to running over HTTP
* [#603](https://github.com/BallAerospace/COSMOS/issues/603) CmdTlmServer invalid constructor argument
* [#614](https://github.com/BallAerospace/COSMOS/issues/614) Pass server message color to message subscriptions
* [#619](https://github.com/BallAerospace/COSMOS/issues/619) Script Runner instrumenting comments and whitespace
* [#630](https://github.com/BallAerospace/COSMOS/issues/630) Add ConfigEditor and CmdSequence to install launcher
* [#647](https://github.com/BallAerospace/COSMOS/issues/647) Make packet item sort consistent
* [#649](https://github.com/BallAerospace/COSMOS/issues/649) Add codecov support

### Bug Fixes:

* [#562](https://github.com/BallAerospace/COSMOS/issues/562) #562 Template protocol should fill Id fields
* [#577](https://github.com/BallAerospace/COSMOS/issues/577) #577 Telemetry Viewer has fatal exception when called with JSON-RPC method display
* [#593](https://github.com/BallAerospace/COSMOS/issues/593) #593 Race condition in Cosmos.kill_thread
* [#607](https://github.com/BallAerospace/COSMOS/issues/607) #607 Support latest version of wkhtmltopdf for pdf creation and properly set working dir
* [#610](https://github.com/BallAerospace/COSMOS/issues/610) #610 target shouldn't report error requiring file in target lib
* [#616](https://github.com/BallAerospace/COSMOS/issues/616) #616 Ignore untested Windows version message in Windows 10
* [#617](https://github.com/BallAerospace/COSMOS/issues/617) #617 Ruby 2.4's inherent Warning class shadows Qt::MessageBox::Warning
* [#633](https://github.com/BallAerospace/COSMOS/issues/633) #633 combo_box is mutating input
* [#639](https://github.com/BallAerospace/COSMOS/issues/639) #639 Partial rendering in config parser should enforce that rendered partials start with underscore
* [#654](https://github.com/BallAerospace/COSMOS/issues/654) #654 Test Runner crashes with no config file
* [#655](https://github.com/BallAerospace/COSMOS/issues/655) #655 Metadata system triggers a nil router error in api.rb with basic setup
* [#659](https://github.com/BallAerospace/COSMOS/issues/659) #659 Hazardous commands throwing errors

### Migration Notes from COSMOS 4.0.x:

Any custom tools in other languages that use the COSMOS API will need to be updated.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

## 4.0.3 / 2017-10-24
{: #v4-0-3}

**Important Bug Fix:** UdpInterface was only working for locahost on earlier versions of COSMOS 4.0.x. Please upgrade to COSMOS 4.0.3 if you need support for UDP.

### New Features:

* [#585](https://github.com/BallAerospace/COSMOS/issues/585) Add packet level config_name

### Maintenance:

None

### Bug Fixes:

* [#590](https://github.com/BallAerospace/COSMOS/issues/590) UdpReadSocket must be created before UdpWriteSocket if read_port == write_src_port

### Migration Notes from COSMOS 3.x:

COSMOS 4 includes several breaking changes from the COSMOS 3.x series.

The first and simplest is that the Command and Telemetry Server now opens an additional port at 7780 by default, that provides a router that will send out each command that the system has sent.  This can allow external systems to also log all commands sent by COSMOS.  For most people this change will be transparent and no updates to your COSMOS configuration will be required.

The second is that the Command and Telemetry Server now always supports a meta data packet called SYSTEM META.  This packet will always contain the MD5 sum for the current running COSMOS configuration, the version of COSMOS running, the version of your COSMOS Project, and the version of Ruby being used.  You can also add your own requirements for meta data with things like the name of the operator currently running the system, or the name of a specific test you are currently running.  In general you shouldn't need to do anything for this change unless you were using the previous metadata functionality in COSMOS.  If you were, then you will need to migrate your meta data to the new SYSTEM META packet, and change the parameters in your CmdTlmServer or TestRunner configurations regarding meta data.  If you weren't using metadata before, then you will probably just notice this new packet in your log files, and in your telemetry stream.

Finally the most exciting breaking change is in how COSMOS interfaces handle protocols.  Before, the COSMOS TCP/IP and Serial interface classes each took a protocol like LENGTH, TERMINATED, etc that defined how packets were delineated by the interface.  Now each interface can take a set of one or more protocols.  This allows COSMOS to much more easily support nested protocols, such as the frame focused protocols of CCSDS.  It also allows for creating helpful reusable protocols such as the new CRC protocol for automatically adding CRCs to outgoing commands and verifying incoming CRCs on telemetry packets.  It's a great change, but if you have any custom interface classes you have written, they will probably require some modification.  See the Interfaces section at cosmosrb.com to see how the new interface classes work. We will also be writing up a blog post to help document the process of upgrading.  Look for this in a week or two.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.


## 4.0.2 / 2017-09-29
{: #v4-0-2}

**Important Bug Fix:** UdpInterface was only working for locahost on earlier versions of COSMOS 4.0.x. Please upgrade to COSMOS 4.0.2 if you need support for UDP.

### New Features:

* [#577](https://github.com/BallAerospace/COSMOS/issues/577) LIMITSBAR widget shouldn't allow RAW
* [#565](https://github.com/BallAerospace/COSMOS/issues/565) Template Protocol support for logging rather than disconnect on timeout

### Maintenance:

* [#551](https://github.com/BallAerospace/COSMOS/issues/551) TlmViewer meta AUTO_TARGET needs parameter
* [#553](https://github.com/BallAerospace/COSMOS/issues/553) Create cosmosrb documentation based on metadata
* [#554](https://github.com/BallAerospace/COSMOS/issues/554) TEMP1 limits getting disabled in demo is confusing

### Bug Fixes:

* [#564](https://github.com/BallAerospace/COSMOS/issues/564) Items with STATES don't respect LIMITS
* [#568](https://github.com/BallAerospace/COSMOS/issues/568) CSV shouldn't call compact
* [#569](https://github.com/BallAerospace/COSMOS/issues/569) combo_box and vertical_message_box don't report correct user selection
* [#580](https://github.com/BallAerospace/COSMOS/issues/580) Udp interface does not work for non-localhost

### Migration Notes from COSMOS 3.8.x:

COSMOS 4 includes several breaking changes from the COSMOS 3.x series.

The first and simplest is that the Command and Telemetry Server now opens an additional port at 7780 by default, that provides a router that will send out each command that the system has sent.  This can allow external systems to also log all commands sent by COSMOS.  For most people this change will be transparent and no updates to your COSMOS configuration will be required.

The second is that the Command and Telemetry Server now always supports a meta data packet called SYSTEM META.  This packet will always contain the MD5 sum for the current running COSMOS configuration, the version of COSMOS running, the version of your COSMOS Project, and the version of Ruby being used.  You can also add your own requirements for meta data with things like the name of the operator currently running the system, or the name of a specific test you are currently running.  In general you shouldn't need to do anything for this change unless you were using the previous metadata functionality in COSMOS.  If you were, then you will need to migrate your meta data to the new SYSTEM META packet, and change the parameters in your CmdTlmServer or TestRunner configurations regarding meta data.  If you weren't using metadata before, then you will probably just notice this new packet in your log files, and in your telemetry stream.

Finally the most exciting breaking change is in how COSMOS interfaces handle protocols.  Before, the COSMOS TCP/IP and Serial interface classes each took a protocol like LENGTH, TERMINATED, etc that defined how packets were delineated by the interface.  Now each interface can take a set of one or more protocols.  This allows COSMOS to much more easily support nested protocols, such as the frame focused protocols of CCSDS.  It also allows for creating helpful reusable protocols such as the new CRC protocol for automatically adding CRCs to outgoing commands and verifying incoming CRCs on telemetry packets.  It's a great change, but if you have any custom interface classes you have written, they will probably require some modification.  See the Interfaces section at cosmosrb.com to see how the new interface classes work. We will also be writing up a blog post to help document the process of upgrading.  Look for this in a week or two.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.


## 4.0.1 / 2017-08-23
{: #v4-0-1}

### New Features:

* [#527](https://github.com/BallAerospace/COSMOS/issues/527) Editing config files should now bring up ConfigEditor
* [#528](https://github.com/BallAerospace/COSMOS/issues/528) ConfigEditor missing some keywords
* [#534](https://github.com/BallAerospace/COSMOS/issues/534) Create ConfigEditor Mac app
* [#536](https://github.com/BallAerospace/COSMOS/issues/536) Clickable canvas objects open screens
* [#542](https://github.com/BallAerospace/COSMOS/issues/543) Automatically populate COMMAND SYSTEM META
* [#543](https://github.com/BallAerospace/COSMOS/issues/543) Allow SYSTEM META items to be read only

### Maintenance:

* None

### Bug Fixes:

* [#533](https://github.com/BallAerospace/COSMOS/issues/533) TestRunner strips all comments when running
* [#538](https://github.com/BallAerospace/COSMOS/issues/538) META_INIT broken
* [#540](https://github.com/BallAerospace/COSMOS/issues/540) Background task packet subscription get_packet broken
* [#547](https://github.com/BallAerospace/COSMOS/issues/547) convert_packet_to_data should copy buffer

### Migration Notes from COSMOS 3.8.x:

COSMOS 4 includes several breaking changes from the COSMOS 3.x series.

The first and simplest is that the Command and Telemetry Server now opens an additional port at 7780 by default, that provides a router that will send out each command that the system has sent.  This can allow external systems to also log all commands sent by COSMOS.  For most people this change will be transparent and no updates to your COSMOS configuration will be required.

The second is that the Command and Telemetry Server now always supports a meta data packet called SYSTEM META.  This packet will always contain the MD5 sum for the current running COSMOS configuration, the version of COSMOS running, the version of your COSMOS Project, and the version of Ruby being used.  You can also add your own requirements for meta data with things like the name of the operator currently running the system, or the name of a specific test you are currently running.  In general you shouldn't need to do anything for this change unless you were using the previous metadata functionality in COSMOS.  If you were, then you will need to migrate your meta data to the new SYSTEM META packet, and change the parameters in your CmdTlmServer or TestRunner configurations regarding meta data.  If you weren't using metadata before, then you will probably just notice this new packet in your log files, and in your telemetry stream.

Finally the most exciting breaking change is in how COSMOS interfaces handle protocols.  Before, the COSMOS TCP/IP and Serial interface classes each took a protocol like LENGTH, TERMINATED, etc that defined how packets were delineated by the interface.  Now each interface can take a set of one or more protocols.  This allows COSMOS to much more easily support nested protocols, such as the frame focused protocols of CCSDS.  It also allows for creating helpful reusable protocols such as the new CRC protocol for automatically adding CRCs to outgoing commands and verifying incoming CRCs on telemetry packets.  It's a great change, but if you have any custom interface classes you have written, they will probably require some modification.  See the Interfaces section at cosmosrb.com to see how the new interface classes work. We will also be writing up a blog post to help document the process of upgrading.  Look for this in a week or two.

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

## 4.0.0 / 2017-08-04
{: #v4-0-0}

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

## 3.9.2 / 2017-05-18
{: #v3-9-2}

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


## 3.9.1 / 2017-03-29
{: #v3-9-1}

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


## 3.8.3 / 2016-12-06
{: #v3-8-3}

### New Features:

* [#230](https://github.com/BallAerospace/COSMOS/issues/230) Make AUTO_TARGETS ignore target folders that have already been manually referenced
* [#257](https://github.com/BallAerospace/COSMOS/issues/257) Increment received_count in packet log reader
* [#264](https://github.com/BallAerospace/COSMOS/issues/264) Validate command/telemetry conversions during startup
* [#292](https://github.com/BallAerospace/COSMOS/issues/292) Target directory for API methods
* [#314](https://github.com/BallAerospace/COSMOS/issues/314) Update .bat files to handle spaces in path
* [#316](https://github.com/BallAerospace/COSMOS/issues/316) Add option to radiobutton widget to be checked by default
* [#326](https://github.com/BallAerospace/COSMOS/issues/326) Script Runner Crash using message_box with boolean parameter
* [#339](https://github.com/BallAerospace/COSMOS/issues/339) Add 'Help' menu item to open cosmosrb.com -> Documentation
* [#340](https://github.com/BallAerospace/COSMOS/issues/340) Packet Viewer - Allow select cell and copy value as text
* [#357](https://github.com/BallAerospace/COSMOS/issues/357) Add support for mixed endianness within tables
* [#359](https://github.com/BallAerospace/COSMOS/issues/359) Table Manager support MIN/MAX UINTX macros

### Maintenance:
* [#349](https://github.com/BallAerospace/COSMOS/issues/349) Optimize cmd() to not build commands twice
* [#362](https://github.com/BallAerospace/COSMOS/issues/362) restore_defaults should take an optional parameter to exclude specified parameters
* [#365](https://github.com/BallAerospace/COSMOS/issues/365) Windows installer can have issues if .gem files are present in same folder
* TestRunner support for newer Bundler (Abstract error when starting)

### Bug Fixes:

* [#322](https://github.com/BallAerospace/COSMOS/issues/322) Udp interface thread does not gracefully shutdown
* [#327](https://github.com/BallAerospace/COSMOS/issues/327) TlmGrapher Screenshot in Linux captures the screenshot dialog box
* [#332](https://github.com/BallAerospace/COSMOS/issues/332) ERB template local variables dont' support strings
* [#338](https://github.com/BallAerospace/COSMOS/issues/338) Setting received_time and received_count on a packet should clear the read conversion cache
* [#342](https://github.com/BallAerospace/COSMOS/issues/342) Cust and Paste Error in top_level.rb
* [#344](https://github.com/BallAerospace/COSMOS/issues/344) CmdTlmServer connect/disconnect button doesn't work after calling connect_interface from script
* [#359](https://github.com/BallAerospace/COSMOS/issues/359) Table Manager doesn't support strings
* [#372](https://github.com/BallAerospace/COSMOS/issues/372) TestRunner reinstantiating TestSuite/Test objects every execution

### Migration Notes from COSMOS 3.7.x:
None

To upgrade to the latest version of COSMOS, run "bundle update cosmos" in your COSMOS project folder.

## 3.8.2 / 2016-07-05
{: #v3-8-2}

### New Features:

### Maintenance:

* COSMOS Downloads graph rake task updates

### Bug Fixes:

* [#303](https://github.com/BallAerospace/COSMOS/issues/303) Need to clear read conversion cache on Packet#clone
* [#304](https://github.com/BallAerospace/COSMOS/issues/304) Win32 Serial Driver clean disconnect
* [#309](https://github.com/BallAerospace/COSMOS/issues/309) Fix Script Runner insert_return when not running

### Migration Notes from COSMOS 3.7.x:
None


## 3.8.1 / 2016-05-12
{: #v3-8-1}

### New Features:

* [#184](https://github.com/BallAerospace/COSMOS/issues/184) Limits Monitor show green for blue limits items
* [#190](https://github.com/BallAerospace/COSMOS/issues/190) Simpler MIN MAX syntax for command definitions
* [#254](https://github.com/BallAerospace/COSMOS/issues/254) Get buffer from commands
* [#259](https://github.com/BallAerospace/COSMOS/issues/259) Proper support for user selected text editor on linux
* [#262](https://github.com/BallAerospace/COSMOS/issues/262) PackerViewer option for listing derived items last
* [#271](https://github.com/BallAerospace/COSMOS/issues/271) Time.formatted option for no microseconds
* [#288](https://github.com/BallAerospace/COSMOS/issues/288) check_tolerance should enforce a positive tolerance
* [#301](https://github.com/BallAerospace/COSMOS/issues/301) Update use of COSMOS_DEVEL

### Maintenance:

* [#268](https://github.com/BallAerospace/COSMOS/issues/268) xtce_converter doesn't support byte order list
* [#277](https://github.com/BallAerospace/COSMOS/issues/277) Test Runner support for Script Runner options
* [#285](https://github.com/BallAerospace/COSMOS/issues/285) xtce converter doesn't support LocationInContainerInBits

### Bug Fixes:

* [#256](https://github.com/BallAerospace/COSMOS/issues/256) Defining initialize method in Cosmos::Test class breaks the class when using Test Selection in TestRunner
* [#273](https://github.com/BallAerospace/COSMOS/issues/273) Wrap Qt::Application.instance in main_thread
* [#287](https://github.com/BallAerospace/COSMOS/issues/287) Installer issue on newer versions of Ubuntu and Debian related to libssl
* [#293](https://github.com/BallAerospace/COSMOS/issues/293) Units applied after a read_conversion that returns a string modifies cached conversion value
* [#294](https://github.com/BallAerospace/COSMOS/issues/294) String#convert_to_value should always just return the starting string if the conversion fails
* [#298](https://github.com/BallAerospace/COSMOS/issues/298) COSMOS IoMultiplexer breaks gems that invoke stream operator on STDOUT/ERR

### Migration Notes from COSMOS 3.7.x:
None

## 3.8.0 / 2016-02-26
{: #v3-8-0}

With this release COSMOS now has initial support for the XTCE Command and Telemetry Definition standard.

### New Features:

* [#251](https://github.com/BallAerospace/COSMOS/issues/251) Create COSMOS XTCE Converter
* [#252](https://github.com/BallAerospace/COSMOS/issues/252) Add polling rate command line option to PacketViewer

### Bug Fixes:

* [#245](https://github.com/BallAerospace/COSMOS/issues/245) TlmGrapher Crashes on Inf
* [#248](https://github.com/BallAerospace/COSMOS/issues/248) Can't script commands containing 'with' in the name

### Migration Notes from COSMOS 3.7.x:
None

## 3.7.1 / 2015-12-29
{: #v3-7-1}

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

## 3.7.0 / 2015-11-25
{: #v3-7-0}

### New Features:

* [#213](https://github.com/BallAerospace/COSMOS/issues/213) Vertical Limits Bar
* [#214](https://github.com/BallAerospace/COSMOS/issues/214) TlmGrapher show full date for plotted points
* [#219](https://github.com/BallAerospace/COSMOS/issues/219) State Color Widget
* [#225](https://github.com/BallAerospace/COSMOS/issues/225) Set Bind Address in UDP interface

### Maintenance:

* [#223](https://github.com/BallAerospace/COSMOS/issues/223) C Extension Improvements

### Bug Fixes:

* [#199](https://github.com/BallAerospace/COSMOS/issues/199) Investigate TlmGrapher Formatted Time Item
* [#211](https://github.com/BallAerospace/COSMOS/issues/211) Background task with arguments not working
* [#217](https://github.com/BallAerospace/COSMOS/issues/217) Graph Right Margin Too Small

### Migration Notes from COSMOS 3.6.x:

1. Background task arguments are now broken out instead of being received as a single array
2. udp_interface now takes an optional argument for bind_address
3. line_graph_script has been significantly updated to support modifying plots from the script.

## 3.6.3 / 2015-10-30
{: #v3-6-3}

### New Features:

* [#200](https://github.com/BallAerospace/COSMOS/issues/200) ScriptRunner Find Dialog Does Not Cross Windows
* [#201](https://github.com/BallAerospace/COSMOS/issues/201) Table Manager to support arbitrary inputs on State Fields
* [#209](https://github.com/BallAerospace/COSMOS/issues/209) Add UTS Timestamp Flag to TlmGrapher Plots

### Maintenance:

* [#194](https://github.com/BallAerospace/COSMOS/issues/194) Allow up to one minute for TlmViewer to start when calling display() from a script
* [#203](https://github.com/BallAerospace/COSMOS/issues/203) load_utility should raise LoadError like load and require
* [#205](https://github.com/BallAerospace/COSMOS/issues/205) Add testing for array and matrix

### Bug Fixes:

* [#191](https://github.com/BallAerospace/COSMOS/issues/191) Installing COSMOS Issue on Windows 7
* [#193](https://github.com/BallAerospace/COSMOS/issues/193) Fix ask() on linux and qt 4.6.2
* [#197](https://github.com/BallAerospace/COSMOS/issues/197) Improve linc interface

### Migration Notes from COSMOS 3.5.x:

None

## 3.6.2 / 2015-08-10
{: #v3-6-2}

### Bug Fixes:

* [#187](https://github.com/BallAerospace/COSMOS/issues/187) Must require tempfile in config_parser.rb on non-windows systems

### Migration Notes from COSMOS 3.5.x:

None

## 3.6.1 / 2015-08-10
{: #v3-6-1}

### Bug Fixes:

* [#185](https://github.com/BallAerospace/COSMOS/issues/185) target.txt order not being preserved

### Migration Notes from COSMOS 3.5.x:

None

## 3.6.0 / 2015-08-07
{: #v3-6-0}

Huge new feature in this release: All COSMOS configuration files are now interpreted with the ERB preprocessor!  This allows you to use Ruby code within the configuration files to help build them.  You can also render partials of common information such as packet headers so you only have to define them once.  See the INST target in the updated Demo project for examples.

### Bug Fixes:

* [#168](https://github.com/BallAerospace/COSMOS/issues/168) Select unreliably unblocks when closing sockets on linux
* [#177](https://github.com/BallAerospace/COSMOS/issues/177) MACRO_APPEND in descending order is broken
* [#179](https://github.com/BallAerospace/COSMOS/issues/179) ScriptRunnerFrame Context Menu Crash
* [#182](https://github.com/BallAerospace/COSMOS/issues/182) Overriding LOG_WRITERS in cmd_tlm_server.txt can cause issues

### New Features:

* [#170](https://github.com/BallAerospace/COSMOS/issues/170) Consider supporting a preprocessor over COSMOS config files
* [#171](https://github.com/BallAerospace/COSMOS/issues/171) Script Runner should have file open and save GUI dialogs
* [#174](https://github.com/BallAerospace/COSMOS/issues/174) Add View in Command Sender in Server

### Maintenance:

* [#80](https://github.com/BallAerospace/COSMOS/issues/80) Investigate performance of nonblocking IO without exceptions

### Migration Notes from COSMOS 3.5.x:

None

## 3.5.3 / 2015-07-14
{: #v3-5-3}

### Bug Fixes:

* [#169](https://github.com/BallAerospace/COSMOS/issues/169) Make windows bat files support running outside of the current directory

### New Features:

* N/A

### Maintenance:

* N/A

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool. All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.1

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments. If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.

## 3.5.2 / 2015-07-14
{: #v3-5-2}

### Bug Fixes:

* [#167](https://github.com/BallAerospace/COSMOS/issues/167) Use updated url for wkhtmltopdf downloads

### New Features:

* [#166](https://github.com/BallAerospace/COSMOS/pull/166) Add install script for Ubuntu

### Maintenance:

* N/A

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool. All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.1

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments. If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.

## 3.5.1 / 2015-07-08
{: #v3-5-1}

This release fixes a bug and completes the installation scripts for linux/mac.

### Bug Fixes:

* [#165](https://github.com/BallAerospace/COSMOS/pull/165) Change launch_tool to tool_launch in Launcher

### New Features:

* N/A

### Maintenance:

* [#102](https://github.com/BallAerospace/COSMOS/issues/102) Create Installation Scripts

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool. All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.1

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments. If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.


## 3.5.0 / 2015-06-22
{: #v3-5-0}

This release contains a lot of new functionality and a key new feature:  The ability to create new COSMOS targets and tools as reusable gems!  This will hopefully allow the open source community to create sharable configuration for a large amount of hardware and allow for community generated tools to be easily integrated.

### Bug Fixes:

* [#153](https://github.com/BallAerospace/COSMOS/issues/153) set_tlm should support settings strings with spaces using the normal syntax
* [#155](https://github.com/BallAerospace/COSMOS/issues/155) Default to not performing DNS lookups

### New Features:

* [#25](https://github.com/BallAerospace/COSMOS/issues/25) Warn users if reading a packet log uses the latest instead of the version specified in the file header
* [#106](https://github.com/BallAerospace/COSMOS/issues/106) Allow the server to run headless
* [#109](https://github.com/BallAerospace/COSMOS/issues/109) Cmd value api
* [#129](https://github.com/BallAerospace/COSMOS/issues/129) Script Runner doesn't syntax highlight module namespacing
* [#133](https://github.com/BallAerospace/COSMOS/issues/133) Add sound to COSMOS alerts
* [#138](https://github.com/BallAerospace/COSMOS/issues/138) Limits Monitor should show what is stale
* [#142](https://github.com/BallAerospace/COSMOS/issues/142) Support gem based targets and tools
* [#144](https://github.com/BallAerospace/COSMOS/issues/144) Never have nothing happen when trying to launch a tool
* [#152](https://github.com/BallAerospace/COSMOS/issues/152) Provide a method to retrieve current suite/group/case in TestRunner
* [#157](https://github.com/BallAerospace/COSMOS/issues/157) Launcher support command line options in combobox
* [#163](https://github.com/BallAerospace/COSMOS/issues/163) Allow message_box to display buttons vertically

### Maintenance:

* [#131](https://github.com/BallAerospace/COSMOS/issues/131) Consolidate Find/Replace logic in the FindReplaceDialog
* [#137](https://github.com/BallAerospace/COSMOS/issues/137) Improve Server message log performance
* [#142](https://github.com/BallAerospace/COSMOS/issues/142) Improve Windows Installer bat file
* [#146](https://github.com/BallAerospace/COSMOS/issues/146) Need support for additional non-standard serial baud rates
* [#150](https://github.com/BallAerospace/COSMOS/issues/150) Improve Win32 serial driver performance

### Migration Notes from COSMOS 3.4.2:

The launcher scripts and .bat files that live in the COSMOS project tools folder have been updated to be easier to maintain and to ensure that the user always sees some sort of error message if a problem occurs starting a tool.  All users should copy the new files from the tools folder in the COSMOS demo folder into their projects as part of the upgrade to COSMOS 3.5.0

COSMOS now disables reverse DNS lookups by default because they can take a long time in some environments.  If you still want to see hostnames when someone connects to a TCP/IP server interface/router then you will need to add ENABLE_DNS to your system.txt file.


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
