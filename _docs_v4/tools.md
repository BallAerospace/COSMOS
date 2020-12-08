---
layout: docs
title: Tools
toc: true
---

## Launcher

Organize and launches all of the applications necessary to control your system.

![Launcher](/img/tools/launcher.png)

- Displays an icon, name, and button to launch each application
- Launch multiple tools with one click
- Performs CRC verification across the COSMOS core files and your project’s files to make sure nothing has been modified
- The same config file works across all platforms (Windows, Mac, Linux)

## Command and Telemetry Server

Connects to everything that makes up your system, logs everything that happens, and shares the data with other tools.

![Command and Telemetry Server](/img/tools/cmd_tlm_server.png)

- Realtime hub for the system: connects to everything that needs to receive commands and send status
- Logs all commands sent and telemetry received
- Provides an API for other tools to send commands, receive telemetry, connect/disconnect interfaces, etc.
- Displays raw versions of commands/telemetry packets
- Performs limits monitoring on telemetry

## Replay

Provides the same interfaces as the Command and Telemetry server but is used to replay telemetry log files. All other tools work as if they are receiving data in real time.

![Replay](/img/tools/replay.png)

- Play data sequentially or reverse
- Quickly slide to specific points in time

## Limits Monitor

Situational awareness of everything that is currently out of limits in your system and everything that has temporarily gone out of limits since it was started.

![Limits Monitor](/img/tools/limits_monitor.png)

- Limits bar widget used to show where in the limits range you are
- Packets and Items can be ignored

## Command Sender

Easily send individual commands.

![Command Sender](/img/tools/cmd_sender.png)

- Select any command by target and command name and then fill out a form with the command parameters
- Command history can be used to resend the same or slightly modified commands
- Send raw data files to inject faults

## Command Sequence

Create and send command sequences.

![Command Sequence](/img/tools/cmd_sequence.png)

- Select any command by target and command name and then fill out a form with the command parameters
- Absolute or relative time tagging
- Export sequences to a custom defined binary format

## Script Runner

Develop and execute test procedures with code completion, line highlighting, syntax checking, and more.

![Script Runner](/img/tools/script_runner.png)

- Simple API to send commands and check telemetry
- Query the user for information
- Currently executing line is highlighted
- Full power of the Ruby programming language available
- Disconnect mode for offline testing
- Debugger for step execution
- Audit commands sent and telemetry checked

## Test Runner

Run test procedures as small repeatable test cases.

![Test Runner](/img/tools/test_runner.png)

- Develop system level tests much like unit tests
- Automatic test report generation
- Test Selection to create custom test suites
- Meta data entry and data package creation
- Includes all features of Script Runner

## Packet Viewer

View any telemetry packet in the system with no extra configuration necessary.

![Packet Viewer](/img/tools/pkt_viewer.png)

- Automatically contains all defined targets, packets, and telemetry items
- Search bar allows you to quickly jump to the packet containing any telemetry item in the system

## Telemetry Viewer

Easily create custom telemetry screens with simple configuration text files.

![Telemetry Viewer](/img/tools/tlm_viewer.png)

- Advanced widgets available to display data
- Search bar allows you to quickly bring up the screen containing the telemetry item you are looking for
- Super easy auto configuration
- Generate screens from within the tool
- Audit that you have a screen for every telemetry point
- Modular to allow for creating your own custom widgets

## Telemetry Grapher

Realtime or offline graphing of any telemetry item.

![Telemetry Grapher](/img/tools/tlm_grapher.png)

- Line and x-y graphs
- One or more telemetry points per plot
- Spread data across multiple plots and multiple tabs
- Easily save and restore configurations
- Search bar to quickly add points to graph
- Built in data analysis such as averaging available

## Data Viewer

Text based data visualization of log files, memory dumps, and event messages.

![Data Viewer](/img/tools/data_viewer.png)

- Display data that does not fit the telemetry screen paradigm well
- Great for log file visualization and for displaying raw memory dumps

## Config Editor

Configuration file editor with contextual help for all the COSMOS configuration files.

![Config Editor](/img/tools/config_editor.png)

- Displays tree view of COSMOS Project
- GUI help with descriptions and drop down options

## Telemetry Extractor

Quickly extract telemetry log files into CSV files with just the data you care about.

![Telemetry Extractor](/img/tools/tlm_extractor.png)

- Process any telemetry log file into CSV data for analysis in other tools (Excel, Matlab, etc)
- Add individual items, whole packets, and every packet from a given target using a search bar or drop downs
- Add text columns (great for adding Excel equations)

## Command Extractor

Extract command log files into human readable text.

![Command Extractor](/img/tools/cmd_extractor.png)

- Select any binary command log and a human readable text file is created

## Handbook Generator

Create easy to read HTML and PDF command and telemetry handbooks.

![Handbook Generator](/img/tools/handbook_generator.png)

- Takes the normal COSMOS config files and outputs them into beautifully formatted HTML and PDF handbooks
- Easily configure output using HTML template files

## Table Manager

Binary file editor.

![Table Manager](/img/tools/table_manager.png)

- Provides a simple GUI for editing binary configuration files
- Provides range checking and overall table validity checks
- Break any binary file into several internal tables
- Easily modified to provide table upload and download capabilities within the tool
