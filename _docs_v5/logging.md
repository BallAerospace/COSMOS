---
layout: docs
title: Logging
toc: true
---

This document describes the COSMOS logging framework and structure.

The COSMOS system creates a number of different logs both for data and for application events. The log file location is defined in the system.txt file by the ['PATH LOGS'](/docs/system/#path) setting. The log files which get created in this directory follow a common naming convention. The first part is a date and time: YYYY*MM_DD_HH_MM_SS*. This is followed by words specific to the COSMOS application. COSMOS applications produce the following logs:

| Application    | Log File Name                            | Description                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| -------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Any            | \<date\>\_exception.txt                  | Exception file which is generated if a COSMOS application crashes. Any user provided interface code, background tasks, conversions, etc can result in an exception file if not properly written.                                                                                                                                                                                                                                                      |
| Any            | \<date\>\_unexpected.txt                 | Unexpected text output. If user code tries to print to the standard output using 'puts', this output is captured and an unexpected log file is created when the application exits.                                                                                                                                                                                                                                                                    |
| Cmd/Tlm Server | \<date\>\_cmd.bin                        | All outgoing command packets                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Cmd/Tlm Server | \<date\>\_tlm.bin                        | All incoming telemetry packets                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Cmd/Tlm Server | \<date\>\_server_messages.txt            | All the server messages which are found in the bottom half of the Command and Telemetry Server application. Server messages are time stamped and categorized as INFO, WARN, or ERROR. Messages include red, yellow, limit violations, limit groups enable/disable, commands, and log file open/close.                                                                                                                                                 |
| Command Sender | \<date\>\_cmdsender_messages.txt         | Commands sent through Command Sender are logged and timestamped.                                                                                                                                                                                                                                                                                                                                                                                      |
| Script Runner  | \<date\>\_sr\_\<filename\>\_messages.txt | Each time a script is run, a new messages log file is created. This log captures any 'puts' output in the script as well as any user input. It also captures user interaction with Script Runner such as clicking the Pause and Stop buttons (as well as Step when debugging).                                                                                                                                                                        |
| Test Runner    | \<date\>\_sr\_\<test\>\_messages.txt     | Each time a test is run, a new messages log file is created. The \<test\> part of the filename is either the Suite name if a Suite is run, Suite_TestGroup if a Test Group is run, or Suite_TestGroup_TestCase if a test case is run. This log captures any 'puts' output in the script as well as any user input. It also captures user interaction with Script Runner such as clicking the Pause and Stop buttons (as well as Step when debugging). |
| Test Runner    | \<date\>\_testrunner_results.txt         | Test Runner test report which indicates the file run, metadata, Test Runner settings (checkboxes), Test Case Results and a summary of the tests run.                                                                                                                                                                                                                                                                                                  |
| Test Runner    | \<date\>\_testrunner_results.zip         | If the Test Runner [CREATE_DATA_PACKAGE](/docs/test_runner/#create_data_package) configuration option is set, a zip file is created containing the the test report, the server messages and the command and telemetry bin files.                                                                                                                                                                                                                      |

# Binary File Structure

The Command and Telemetry Server binary log files contain command and telemetry packets. Each log file starts with a 128 byte header that is used internally by COSMOS to denote the version of definition files that were used when the file was created.

| Item | Data Type | Description |
| Marker | 8 byte ASCII String | The ASCII string 'COSMOS2*' |
| Type | 4 byte ASCII String | Either 'CMD*' for command logs or 'TLM\_' for Telemetry logs |
| MD5 | 32 byte ASCII String | 32 byte MD5 Sum calculated over the configuration files being used |
| Underscore | 1 byte ASCII String | An Underscore character |
| Hostname | 83 byte ASCII String | Left justified hostname of the computer that created the file |

The file header is followed by command or telemetry packets (depending on the log type), each with a Big Endian header as follows. Note this is the same binary header used by the preidentified streaming protocol:

| Item | Data Type | Description |
| Write Flags | 8-bit unsigned integer | 0x80 indicates whether the data is stored telemetry (see below). 0x40 indicates there is extra data following this byte. 0x3F bits are currently undefined. (since 4.3.0) |
| Extra Length (optional) | 32-bit unsigned big endian integer | Number of extra bytes (Optional, depends on Write Flags) (since 4.3.0) |
| Extra (optional) | 32-bit unsigned big endian integer | JSON encoded extra data (Optional, depends on Write Flags) (since 4.3.0) |
| Time Seconds | 32-bit unsigned big endian integer | Seconds since Unix epoch (Jan 1st, 1970 – Midnight) |
| Time Microseconds | 32-bit unsigned big endian integer | Microseconds of Second since Unix epoch (Jan 1st, 1970 – Midnight) |
| Target Name Length | 8-bit unsigned integer | Length in bytes of the target name |
| Target Name | Variable length ASCII String | String that indicates the name of the target that the data was sourced from. |
| Packet Name Length | 8-bit unsigned integer | Length in bytes of the packet name |
| Packet Name | Variable length ASCII String | String that indicates the name of the packet of data. |
| Packet Length | 32-bit unsigned big endian integer | Length in bytes of the packet |
| Packet | Variable length block of data | The binary data packet (endianness defined by packet definition) |

The variable length nature of command and telemetry packets requires a log parser to start from the beginning of each log file when processing packets.

If the Write Flags indicate the data is stored telemetry (MSB set) COSMOS processes and stores the data in the telemetry log file but does not update the current value table. Thus stored telemetry does not affect displays or scripts.
