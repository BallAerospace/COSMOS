---
layout: docs
title: Plugins
toc: true
---

## Introduction

This document provides the information necessary to configure a COSMOS plugin. Plugins are how you configure and extend COSMOS 5.  

Plugins are where you define targets (and their corresponding command and telemetry packet definitions), where you configure the interfaces needed to talk to targets, where you can define routers to stream raw data out of COSMOS, how you can add new tools to the COSMOS user interface, and how you can run additional microservices to provide new functionality.

Each plugin is built as a Ruby gem and thus has a <plugin>.gemspec file which builds it. Plugins have a plugin.txt file which declares all the variables used by the plugin and how to interface to the target(s) it contains.

## Concepts

### Target

Targets are the external pieces of hardware and/or software that COSMOS communicates with.  These are things like Front End Processors (FEPs), ground support equipment (GSE), custom software tools, and pieces of hardware like satellites themselves.  A target is anything that COSMOS can send commands to and receive telemetry from.

### Interface

Interfaces implement the physical connection to one or more targets.  They are typically ethernet connections implemented using TCP or UDP but can be other connections like serial ports.  Interfaces send commands to targets and receive telemetry from targets.

### Router

Routers flow streams of telemetry packets out of COSMOS and receive streams of commands into COSMOS.  The commands are forwarded by COSMOS to associated interfaces.  Telemetry comes from associated interfaces.

### Tool

COSMOS Tools are web-based applications the communicate with the COSMOS APIs to perform takes like displaying telemetry, sending commands, and running scripts.

### Microservice

Microservices are persistent running backend code that runs within the COSMOS environment.  They can process data and perform other useful tasks.

## Plugin Directory Structure

COSMOS plugins have a well-defined directory structure as follows:

| Folder / File | Description |
| ------------- | ------------ |
| plugin.txt | Configuration file for the plugin.  This file is required and always named exactly plugin.txt.  See later in this document for the format. |
| LICENSE.txt | License for the plugin.  COSMOS Plugins should be licensed in a manner compatible with the AGPLv3, unless they are designed only for use with COSMOS Enterprise Edition (or only for use at Ball), in which case they can take on any license as desired. |
| cosmos-PLUGINNAME.gemspec or cosmosc2-PLUGINNAME.gemspec | This file should have the name of the plugin with a .gemspec extension.  For example cosmos-demo.gemspec.   The name of this file is used in compiling the plugin contents into the final corresponding <Plugin Name>-<Version>.gem plugin file.  ie. cosmos-demo-5.0.0.gem.  COSMOS plugins should always begin with the cosmos- or cosmosc2- prefix to make them easily identifiable in the Rubygems repository. The contents of this file take on the Rubygems spec format as documented at: https://guides.rubygems.org/specification-reference/ |
| Rakefile | This is a helper ruby Rakefile used to build the plugin.  In general, the exact same file as provided with the COSMOS demo plugins can be used, or other features can be added as necessary for your plugin project.  This file is typically just used to support building the plugin by running "rake build VERSION=X.X.X" where X.X.X is the plugin version number.  A working Ruby installation is required.  |
| README.md | Use this file to describe your plugin.  It is typically a markdown file that supports nice formatting on Github. |
| targets/ | This folder is required if any targets are defined by your plugin.  All target configuration is included under this folder. It should contain one or more target configurations |
| targets/TARGETNAME | This is a folder that contains the configuration for a specific target named TARGETNAME.  The name is always defined in all caps.  For example: targets/INST.   This is typically the default name of the target, but well-designed targets will allow themselves to be renamed at installation. All subfolders and files below this folder are optional and should be added as needed. |
| targets/TARGETNAME/cmd_tlm | This folder contains the command and telemetry definition files for the target. These files capture the format of the commands that can be sent to the target, and the telemetry packets that are expected to be received by COSMOS from the target. Note that the files in this folder are processed in alphabetical order by default. That can matter if you reference a packet in another file (it should already have been defined). See the Command and Telemetry Configuration Guides for more information. |
| targets/TARGETNAME/data | Use this folder to store any general data that is needed by the target.  For example, any image files would be stored here. |
| targets/TARGETNAME/lib | This folder contains any custom code required by the target.  Good examples of custom code are custom Interface classes and protocols.  See the Interface documentation for more information. Try to give any custom code a unique filename that starts with the name of the target.  This can help avoid name conflicts that can occur if two different targets create a custom code file with the same filename. |
| targets/TARGETNAME/procedures | This folder contains target specific procedures and helper methods which exercise functionality of the target. These procedures should be kept simple and only use the command and telemetry definitions associated with this target. See the Scripting Guide for more information. |
| targets/TARGETNAME/screens | This folder contains telemetry screens for the target. See Screen Configuration for more information.  |
| targets/TARGETNAME/target.txt | This file contains target specific configuration such as which command parameters should be ignored by Command Sender. See Target Configuration for more information. |
| microservices/ | This folder is required if any microservices are defined by your plugin.  All microservice code and configuration is included in this folder. It should contain one or more MICROSERVICENAME subfolders |
| microservices/MICROSERVICENAME | This is a folder that contains the code and any necessary configuration for a specific microservice named MICROSERVICENAME.  The name is always defined in all caps.  For example: microservices/EXAMPLE.   This is typically the default name of the microservice, but well-designed microservices will allow themselves to be renamed at installation. All subfolders and files below this folder are optional and should be added as needed. |
| tools/ | This folder is required if any tools are defined by your plugin.  All tool code and configuration is included in this folder. It should contain one or more toolname subfolders |
| tools/toolname | This is a folder that contains all the files necessary to serve a web-based tool named toolname.  The name is always defined in all lowercase.  For example: tools/base.   Due to technical limitations, the toolname must be unique and cannot be renamed at installation. All subfolders and files below this folder are optional and should be added as needed. |

## plugin.txt Configuration File

A plugin.txt configuration file is required for any COSMOS plugin.   It declares the contents of the plugin and provides variables that allow the plugin to be configured at the time it is initially installed or upgraded.
This file follows the standard COSMOS configuration file format of keywords followed by zero or more space separated parameters.  The following keywords are supported by the plugin.txt config file:

{% cosmos_meta plugins.yaml %}
