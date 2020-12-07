---
layout: docs
title: Table Manager
toc: true
---

This document describes Table Manager configuration file and command line parameters.

{% cosmos_meta table_manager.yaml %}

## Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/table_manager/ExampleTableDefinition.txt**

{% highlight bash %}

# Define tables by: TABLE, name, description, endian

# name and description are strings contained in double quotes

# endian is either BIG_ENDIAN or LITTLE_ENDIAN

TABLE "Master Table Map" "The one table to rule them all" ONE_DIMENSIONAL BIG_ENDIAN 1

# Each element in a UNIQUE table is defined as follows:

# name, description, type, bit size, display type, min, max, default

# type must be INT or UNIT

# display type must be DEC, HEX, STATE

# add -U to make DEC or HEX uneditable, i.e. DEC-U or HEX-U

# if min or max are too large for the type they will be set to the types max

PARAMETER "Param1" "The first parameter" INT 32 STATE 0 1 0
STATE DEFAULT 0
STATE USER 1
PARAMETER "Param2" "The second parameter" INT 32 STATE 0 1 1
STATE DEFAULT 0
STATE USER 1
PARAMETER "Param3" "The third parameter" STRING 80 STRING ""
PARAMETER "Param4" "The fourth parameter" UINT 8 HEX MIN MAX MAX
PARAMETER "PAD" "Unused padding" INT 576 HEX-U 0 0 0

TABLE "Trailer" "Data appended to a table file" ONE_DIMENSIONAL BIG_ENDIAN 2
PARAMETER "File ID" "Uneditable file id" UINT 16 DEC-U 0 65535 4
PARAMETER "Version ID" "User defined version id" UINT 16 DEC MIN_UINT16 MAX_UINT16 1
PARAMETER "CRC32" "Auto-generated CRC" UINT 32 HEX-U MIN MAX 0
{% endhighlight %}

{% cosmos_cmd_line TableManager %}
