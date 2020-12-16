---
layout: docs
title: Tools
toc: true
---

## Navigation

The left side of every COSMOS web page can be opened up to display the available tools.
This list is updated when new COSMOS gems are installed which add tools.

![Launcher](/img/v5/navigation.png)

## Command and Telemetry Server

Displays information about the active targets and interfaces.

![Command and Telemetry Server](/img/v5/cmd_tlm_server.png)

- Displays interfaces and associated counters
- Displays raw versions of commands/telemetry packets

## Limits Monitor

Situational awareness of everything that is currently out of limits in your system and everything that has temporarily gone out of limits since it was started.

![Limits Monitor](/img/v5/limits_monitor.png)

- Limits bar widget used to show where in the limits range you are
- Packets and Items can be ignored

## Command Sender

Easily send individual commands.

![Command Sender](/img/v5/command_sender.png)

- Select any command by target and command name and then fill out a form with the command parameters
- Command history can be used to resend the same or slightly modified commands

## Script Runner

Develop and execute test procedures with line highlighting, syntax checking, and more. Also supports organization of scripts into repeatable scripts with an auto-generated report.

![Script Runner](/img/v5/script_runner.png)

- Simple API to send commands and check telemetry
- Query the user for information
- Currently executing line is highlighted
- Full power of the Ruby programming language available
- Disconnect mode for offline testing
- Debugger for step execution
- Script organization by Script, Group, Suite
- Automatic report generation

## Packet Viewer

View any telemetry packet in the system with no extra configuration necessary.

![Packet Viewer](/img/v5/packet_viewer.png)

- Automatically contains all defined targets, packets, and telemetry items
- Right click to get detailed item information

## Telemetry Viewer

Easily create custom telemetry screens with simple configuration text files.

![Telemetry Viewer](/img/v5/telemetry_viewer.png)

- Advanced widgets available to display data
- Generate screens from within the tool
- Audit that you have a screen for every telemetry point
- Modular to allow for creating your own custom widgets

## Telemetry Grapher

Realtime or offline graphing of any telemetry item.

![Telemetry Grapher](/img/v5/telemetry_grapher.png)

- One or more telemetry points per plot
- Spread data across multiple plots
- Easily save and restore configurations

## Extractor

Quickly extract command and telemetry into CSV files with just the data you care about.

![Extractor](/img/v5/extractor.png)

- Process items into CSV data for analysis in other tools (Excel, Matlab, etc)
- Add individual items, whole packets, and every packet from a given target
