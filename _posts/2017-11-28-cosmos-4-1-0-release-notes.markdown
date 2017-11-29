---
layout: news_item
title: 'COSMOS 4.1.0 Release Notes'
date: 2017-11-28 12:00:00 -0700
author: jmthomas
version: 4.1.0
categories: [post]
---

COSMOS 4.1 has been released and several new noteworthy features were released which weren't fully captured by the recent [release description](/news/2017/11/17/cosmos-4-1-0-released/). This post will break down the highlights from the new features, maintence items, and bug fixes from the 4.1.0 release.

## Replay Tool Enhancements

I think the best new feature in COSMOS 4.1.0 is the ability of the Reply tool to work side by side with the Command and Telemetry Server ([#559](https://github.com/BallAerospace/COSMOS/issues/559)). This change actually affects far more than just the Replay tool and the Server because a new "Replay Mode" was built into Data Viewer, Limits Monitor, Packet Viewer, Telemetry Grapher, and Telemetry Viewer.

Replay also got a cosmetic upgrade to look more like the Command and Telemetry Server. Here's the new Replay in action:

![Replay](/img/2017_11_28_replay.png)

Replay now has tabs for Targets, Cmd Packets, Tlm Packets, Routers, and Status which correspond to the same tabs in the Server. These tabs count the number of packets being processed by Replay. Thus if you rewind the file and play it back, the counts simply keep incrementing.

Here's a screenshot of Packet Viewer displaying data in this new Replay mode:

![Packet Viewer Replay](/img/2017_11_28_packet_viewer_replay.png)

Here's another screenshot of Telemetry Grapher displaying data in this new Replay mode:

![Packet Viewer Replay](/img/2017_11_28_tlm_grapher_replay.png)

You'll notice the tools have a new File menu option to toggle the Replay mode which displays a green "Replay Mode" bar to visually indicate the tool is no longer processing real-time data.

## Zip Saved Configuration Data

Issue [#579](https://github.com/BallAerospace/COSMOS/issues/579) was implemented to zip up the COSMOS saved configuration files. This makes configuration managing these saved configurations much easier since you only have to check in a single zip file instead of a folder containing dozens of files and folders.

If you're not familiar with saved configurations, let me explain why this is important. When COSMOS starts, it parses the configuration files, calculates the MD5 sum, and puts a copy of the configuration in outputs/saved_config (by default). You should always configuration manage these files in the saved_config directory to allow COSMOS to parse old binary files created by that configuration. The only exception is during COSMOS configuration development when you're certain you no longer need to parse old telemetry bin files.

As an example of how these saved configurations work, consider that you collect data during a test. Next you modify the configuration by adding some telemetry items to a packet which increases the packet length. If you try to parse the old binary file, COSMOS would complain that the binary packet is not long enough to match the new definition. However, if you save the old configuration, COSMOS would match the MD5 sum in the packet with the saved configuration and load the configuration to parse the packet. Note that if COSMOS can't find the saved configuration it uses the current configuration.

## Better Step Debugging

Issue [#620](https://github.com/BallAerospace/COSMOS/issues/620) was to move the Script Runner Step button next to the Start, Pause, Stop buttons rather than down in the debugging pane. This should make it a lot easier to use the Step feature when debugging scripts. Here's a screenshot of a simple script I started using the Step button (available when you enable Debugging via the Script / Toggle Debug menu).

![Script Runner Debug](/img/2017_11_28_script_runner_debug.png)

Issue [#619](https://github.com/BallAerospace/COSMOS/issues/619) was implemented to prevent Script Runner from instrumenting comments and whitespace when running scripts. This should also make debugging scripts easier as you don't have to step over a bunch of comments or whitespace.

## API over HTTP

As Ryan mentioned in the [4.1 Release Notes](/news/2017/11/17/cosmos-4-1-0-released/), issue [#510](https://github.com/BallAerospace/COSMOS/issues/510) was created to move the COSMOS API from our custom protocol to HTTP. While this change is transparent to the user, it should make it easier for other languages and tools to interface with the COSMOS system in the future.

## Bug Fixes

There were a number of bug fixes as noted in the [4.1 Release Notes](/news/2017/11/17/cosmos-4-1-0-released/). [#617](https://github.com/BallAerospace/COSMOS/issues/617) and [#659](https://github.com/BallAerospace/COSMOS/issues/659) were both related to Ruby 2.4.2 which is the new Ruby version in COSMOS 4.0. Ruby 2.4 is the latest version of Ruby which provides performance improvements you can read about on [ruby-lang.org](https://www.ruby-lang.org/en/news/2016/12/25/ruby-2-4-0-released/). [#616](https://github.com/BallAerospace/COSMOS/issues/616) addresses an annoying message generating by QT on Windows 10. [#655](https://github.com/BallAerospace/COSMOS/issues/655) addresses an issue with using COLLECT_METADATA in the basic "install" version of COSMOS. [#633](https://github.com/BallAerospace/COSMOS/issues/633) fix a bug where the prompt_vertical_message_box and prompt_combo_box scripting methods were mutating the input parameters. If you're using those scripting methods, you should upgrade to COSMOS 4.1.

There were a number of other enhancements and bug fixes but the previous list is a compelling reason to upgrade to COSMOS 4.1 today!
