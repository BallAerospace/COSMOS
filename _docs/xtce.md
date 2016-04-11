---
layout: docs
title: XTCE Support
permalink: /docs/xtce/
---

Ball Aerospace COSMOS now has support for the <a href="http://www.omg.org/space/xtce/" target="_blank">XTCE Command and Telemetry Definition Standard</a>. This is an open standard designed to allow command and telemetry definitions to be transferred between different ground systems. COSMOS can run directly using the .xtce files, or can convert them into the COSMOS configuration file format.  

## Running COSMOS using an .xtce definition file

A single .xtce file containing the command and telemetry definitions for a target can be used in place of the normal COSMOS command and telemetry definition files.  Simply place the target's .xtce file in the target's cmd_tlm folder and COSMOS will use it for the command and telemetry definitions.

## Converting a .xtce file into a COSMOS configuration

Use the following command to convert a .xtce file into COSMOS configuration files.  The converted configuration files will be placed into a target folder in the given output directory.

```
xtce_converter --import <xtce_filename> <output_dir>
```

## Converting a COSMOS Configuration to XTCE

Use the following command to convert your current cosmos project into .xtce files, one per target.  The converted .xtce files will be placed into a target folder in the given output directory.

```
xtce_converter --export <output_dir>
```

## High-level Overview of Current Support

 1. Integer, Float, Enumerated, String, and Binary Parameter/Argument Types are Supported
 1. All DataEncodings are supported
 1. Telemetry and Commands are Supported
 1. Packet Identification is supported
 1. States are supported
 1. Units are supported
 1. PolynomialCalibrators are supported
 1. Only one SpaceSystem per .xtce file
 1. Packets should not have gaps between items

## Supported Elements and Attributes

The following elements and associated attributes are currently supported.

 * SpaceSystem
 * TelemetryMetaData
 * CommandMetaData
 * ParameterTypeSet
 * EnumerationList
 * ParameterSet
 * ContainerSet
 * EntryList
 * DefaultCalibrator
 * DefaultAlarm 
 * RestrictionCriteria
 * ComparisonList
 * MetaCommandSet
 * DefaultCalibrator
 * ArgumentTypeSet
 * ArgumentList
 * ArgumentAssignmentList
 * EnumeratedParameterType
 * EnumeratedArgumentType
 * IntegerParameterType
 * IntegerArgumentType
 * FloatParameterType
 * FloatArgumentType
 * StringParameterType
 * StringArgumentType
 * BinaryParameterType
 * BinaryArgumentType
 * IntegerDataEncoding
 * FloatDataEncoding
 * StringDataEncoding
 * BinaryDataEncoding'
 * SizeInBits
 * FixedValue
 * UnitSet
 * Unit
 * PolynomialCalibrator
 * Term
 * StaticAlarmRanges
 * WarningRange
 * CriticalRange
 * ValidRange
 * Enumeration
 * Parameter
 * Argument
 * ParameterProperties
 * SequenceContainer
 * BaseContainer
 * LongDescription
 * ParameterRefEntry
 * ArgumentRefEntry
 * BaseMetaCommand
 * Comparison
 * MetaCommand
 * BaseMetaCommand
 * CommandContainer
 * ArgumentAssignment

## Ignored Elements

The following elements are simply ignored by COSMOS:

 * Header
 * AliasSet
 * Alias

## Unsupported Elements

Any elements not listed above are currently unsupported. Near term support for the following elements and features are planned and priority will be determined by user requests.

 * SplineCalibrator
 * Alternate methods of specifying offsets into containers
 * Output to the XUSP standard
 * Additional Data Types
 * Container References

If there is a particular element or feature you need supported please submit a ticket on Github.
