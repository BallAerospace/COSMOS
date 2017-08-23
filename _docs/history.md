---
layout: docs
title: Release History
permalink: "/docs/history/"
---

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
