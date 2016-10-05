---
layout: docs
title: Command and Telemetry Configuration
permalink: /docs/cmdtlm/
---

<div class="toc">
{% capture toc %}{% include cmdtlm_toc.md %}{% endcapture %}
{{ toc | markdownify }}
</div>

## Command Definition Files

Command definition files define the command packets that can be sent to COSMOS targets. One large file can be used to define the command packets, or multiple files can be used at the user's discretion. Command definition files are placed in the config/TARGET/cmd_tlm directory and are processed alphabetically. Therefore if you have some command files that depend on others, e.g. they override or extend existing commands, they must be named last. Due to the way the [ASCII Table](http://www.asciitable.com/) is structured, files beginning with capital letters are processed before lower case letters. To force a file to be processed last either prepend it with 'z' or '~'.

<div style="clear:both;"></div>

## **Command Keywords:**

### COMMAND

The COMMAND keyword designates the start of a new command packet.

| Parameter | Description | Required |
|-----------|------------|---------|
| Target Name | Name of the target this command is associated with | Yes |
| Command Name | Name of this command. Also referred to as its mnemonic. Must be unique to commands to this target. Ideally will be as short and clear as possible. | Yes |
| BIG_ENDIAN or LITTLE_ENDIAN | Indicates if the data in this command is to be sent in Big Endian or Little Endian format. | Yes |
| Description | Description of this command. Must be enclosed with "" | No |

Example Usage:
{% highlight bash %}
COMMAND COSMOS START_LOGGING BIG_ENDIAN "Starts logging"
{% endhighlight %}

### SELECT_COMMAND

The SELECT_COMMAND keyword selects an existing command packet for editing.

| Parameter | Description | Required |
|-----------|------------|---------|
| Target Name | Name of the target this command is associated with | Yes |
| Command Name | Name of this command. Also referred to as its mnemonic. | Yes |

Example Usage:
{% highlight bash %}
SELECT_COMMAND COSMOS START_LOGGING
{% endhighlight %}

## Command Modifiers

The following keywords modify a command and are only applicable after the COMMAND or SELECT_COMMAND keywords. They are typically indented within the definition file to show ownership to the previously defined command.

### HAZARDOUS

Designates the current command as a hazardous command. This affects scripts and the Command Sender tool by popping up a dialog asking for confirmation before sending the command.

| Parameter | Description | Required |
|-----------|------------|---------|
| Description | Why the command is hazardous. Must be enclosed with "" | No |

### PARAMETER

The PARAMETER keyword defines a command parameter in the current command.

<table>
  <tr><th>Parameter</th><th>Description</th><th>Required</th></tr>
  <tr><td>Name</td><td>Name of the parameter. Must be unique within the command.</td><td>Yes</td></tr>
  <tr><td>Bit Offset</td><td>Bit offset into the command packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters.</td><td>Yes</td></tr>
  <tr><td>Bit Size</td><td>Bit size of this parameter. Zero or Negative values may be used to indicate that a string fills the packet up to the offset from the end of the packet specified by this value. If Bit Offset = 0 and Bit Size = 0 then this is a derived parameter and the Data Type must be set to 'DERIVED'.</td><td>Yes</td></tr>
  <tr><td>Data Type</td><td>Data Type of this parameter. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0.</td><td>Yes</td></tr>
  <tr>
    <td>Minimum Value</td>
    <td>
      Minimum allowed value for this parameter (Not given if Data Type = STRING or BLOCK)
      The following special constants may be given for common values:
      <table>
        <tr><th>Constant</th><th>Value</th></tr>
        <tr><td>MIN_INT8</td><td>-128</td></tr>
        <tr><td>MAX_INT8</td><td>127</td></tr>
        <tr><td>MIN_INT16</td><td>-32768</td></tr>
        <tr><td>MAX_INT16</td><td>32767</td></tr>
        <tr><td>MIN_INT32</td><td>-2147483648</td></tr>
        <tr><td>MAX_INT32</td><td>2147483647</td></tr>
        <tr><td>MIN_INT64</td><td>-9223372036854775808</td></tr>
        <tr><td>MAX_INT64</td><td>9223372036854775807</td></tr>
        <tr><td>MIN_UINT8</td><td>0</td></tr>
        <tr><td>MAX_UINT8</td><td>255</td></tr>
        <tr><td>MIN_UINT16</td><td>0</td></tr>
        <tr><td>MAX_UINT16</td><td>65535</td></tr>
        <tr><td>MIN_UINT32</td><td>0</td></tr>
        <tr><td>MAX_UINT32</td><td>4294967295</td></tr>
        <tr><td>MIN_UINT64</td><td>0</td></tr>
        <tr><td>MAX_UINT64</td><td>18446744073709551615</td></tr>
        <tr><td>MIN_FLOAT32</td><td>-3.402823e38</td></tr>
        <tr><td>MAX_FLOAT32</td><td>3.402823e38</td></tr>
        <tr><td>MIN_FLOAT64</td><td>-1.7976931348623157e308</td></tr>
        <tr><td>MAX_FLOAT64</td><td>1.7976931348623157e308</td></tr>
        <tr><td>NEG_INFINITY</td><td>-Float::INFINITY</td></tr>
        <tr><td>POS_INFINITY</td><td>Float::INFINITY</td></tr>
      </table>
    </td>
    <td>Yes</td>
  </tr>
  <tr><td>Maximum Value</td><td>Maximum allowed value for this parameter (Not given if Data Type = STRING or BLOCK) See PARAMETER#Minimum Value for a list of special constants like MIN_UINT16 that may be used for this field.</td><td>Yes</td></tr>
  <tr><td>Default Value</td><td>Default value for this parameter. You must provide a default but if you mark the parameter REQUIRED then scripts will be forced to specify a value. See PARAMETER#Minimum Value for a list of special constants like MIN_UINT16 that may be used for this field.</td><td>Yes</td></tr>
  <tr><td>Description</td><td>Description for this parameter. Must be enclosed with ""</td><td>No</td></tr>
</table>

Example Usage:
{% highlight bash %}
PARAMETER SYNC 0 32 UINT 0xDEADBEEF 0xDEADBEEF 0xDEADBEEF "Sync pattern"
PARAMETER VALUE 32 32 FLOAT 0 10.5 2.5
PARAMETER LABEL 64 0 STRING "COSMOS" "The label to apply"</pre>
{% endhighlight %}

### APPEND_PARAMETER

The APPEND_PARAMETER keyword appends a command parameter to the end of the current command. Parameter details are the same as for the PARAMETER keyword except Bit Offset is not used. This is the preferred way to declare parameters as it allows for adding and removing parameters without having to recalculate bit offsets for all other parameters.

Example Usage:
{% highlight bash %}
APPEND_PARAMETER SYNC 32 UINT 0xDEADBEEF 0xDEADBEEF 0xDEADBEEF"Sync pattern"
APPEND_PARAMETER VALUE 32 FLOAT 0 10.5 2.5
APPEND_PARAMETER LABEL 0 STRING "COSMOS" "The label to apply"
{% endhighlight %}

### ID_PARAMETER

Much like the PARAMETER keyword, the ID_PARAMETER keyword defines a command parameter in the current command. In addition, ID_PARAMETER(s) are used to identify a command given a binary array of data. A command packet may have one or more ID_PARAMETERs, all of which must match the binary data for the command to be identified.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the parameter. Must be unique within the command. | Yes |
| Bit Offset | Bit offset into the command packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters. | Yes |
| Bit Size | Bit size of this parameter. Zero or Negative values may be used to indicate that a string fills the packet up to the offset from the end of the packet specified by this value. If Bit Offset = 0 and Bit Size = 0 then this is a derived parameter and the Data Type must be set to 'DERIVED'. | Yes |
| Data Type | Data Type of this parameter. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0. | Yes |
| Minimum Value | Minimum allowed value for this parameter (Not given if Data Type = STRING or BLOCK) See PARAMETER#Minimum Value for a list of special constants like MIN_UINT16 that may be used for this field. | Yes |
| Maximum Value | Maximum allowed value for this parameter (Not given if Data Type = STRING or BLOCK) See PARAMETER#Minimum Value for a list of special constants like MIN_UINT16 that may be used for this field. | Yes |
| ID Value | Identification value for this parameter. The binary data must match this value for the buffer to be identified as this packet. | Yes |
| Description | Description for this parameter. Must be enclosed with "" | No |

Example Usage:
{% highlight bash %}
ID_PARAMETER OPCODE 32 32 UINT 2 2 2 "Opcode identifier"
{% endhighlight %}

### APPEND_ID_PARAMETER

The APPEND_ID_PARAMETER keyword appends an ID command parameter to the end of the current command. Parameter details are the same as for the ID_PARAMETER keyword except Bit Offset is not used.

Example Usage:
{% highlight bash %}
APPEND_ID_PARAMETER OPCODE 32 UINT 2 2 2 "Opcode identifier"
{% endhighlight %}

### ARRAY_PARAMETER

The ARRAY_PARAMETER keyword defines a command parameter in the current command that is an array.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the parameter. Must be unique within the command. | Yes |
| Bit Offset | Bit offset into the command packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters. | Yes |
| Bit Size of Each Item | Bit size of each array item. Must be greater than or equal to 0. | Yes |
| Data Type of Each Item | Data Type of each array item. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0. | Yes |
| Total Bit Size of Array | Total Bit Size of the Array. Zero or Negative values may be used to indicate the array fills the packet up to the offset from the end of the packet specified by this value. | Yes |
| Description | Description for this parameter. Must be enclosed with "". | No |

Example Usage:
{% highlight bash %}
ARRAY_PARAMETER ARRAY 64 64 FLOAT 640 "Array of 10 64bit floats"
{% endhighlight %}

### APPEND_ARRAY_PARAMETER

The APPEND_ARRAY_PARAMETER keyword appends an array command parameter to the end of the current command. Parameter details are the same as for the ARRAY_PARAMETER keyword except Bit Offset is not used.

Example Usage:
{% highlight bash %}
APPEND_ARRAY_PARAMETER ARRAY 64 FLOAT 640 "Array of 10 64bit floats"
{% endhighlight %}

### SELECT_PARAMETER

The SELECT_PARAMETER keyword selects an existing command parameter for editing in the current command.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the parameter to select for modification | Yes |

Example Usage:
{% highlight bash %}
SELECT_COMMAND COSMOS START_LOGGING
  SELECT_PARAMETER LABEL
{% endhighlight %}

### MACRO_APPEND_START and MACRO_APPEND_END

The MACRO_APPEND_START keyword is used to create a list of command parameters which are appended to the current command. Each of these parameters will be repeated with a number appended to their names to form a list of command parameters with a unique mnemonic for each parameter.

| Parameter | Description | Required |
|-----------|------------|---------|
| First Number in Range | First value that will be appended to the parameter mnemonic | Yes |
| Last Number in Range | Last number that will be appended to the parameter mnemonic | Yes |
| Format String | An optional format string that defaults to "%s%d". Where the %s represents the constant portion of the items mnemonic and the %d represents the number in the range that is appended. For example, with a range of 1 to 2 and two items named VALUE and DATA, the format string "%s_%d" would create the mnemonics VALUE_1, DATA_1, VALUE_2, and DATA_2. | No |

Example Usage:
{% highlight bash %}
MACRO_APPEND_START 1 2 "%s_%d"
  APPEND_PARAMETER VALUE 16 UINT 0 5 1 "Value"
  APPEND_PARAMETER DATA 16 UINT 0 5 2 "Data"
MACRO_APPEND_END
{% endhighlight %}

This results in a command with the following mnemonics: VALUE_1, DATA_1, VALUE_2, and DATA_2. All VALUE parameters will have the same default of 1 and all DATA parameters have the same default of 2. Note that due to the dynamic nature of this keyword you must use the APPEND variation of the PARAMETER keywords.

### DISABLE_MESSAGES

Disable the COSMOS Command and Telemetry Server from printing cmd(...) messages for this command.  Commands are still logged.

### META

The META keyword stores metadata for the current command that can be used by custom tools for various purposes (For example to store additional information needed to generate FSW header files).

| Parameter | Description | Required |
|-----------|------------|---------|
| Meta Name | Name of the metadata to store | Yes |
| Meta Values | One or more values to be stored for this Meta Name | No |

Example Usage:
{% highlight bash %}
META FSW_TYPE "struct command"
{% endhighlight %}

## Parameter Modifiers

The following keywords modify a parameter and are only applicable after the various PARAMETER keywords as defined above. They are typically indented within the definition file to show ownership to the previously defined parameter.

### REQUIRED

Declares that when sending the command via Script Runner a value must always be given for the current command parameter. This prevents the user from relying on a default value. Note that this does not affect Command Sender which will still populate the field with the default value provided in the PARAMETER definition.

### FORMAT_STRING

The FORMAT_STRING keyword adds printf style formatting to a command parameter. This can be used to set how default command parameter values are displayed in Command Sender.

| Parameter | Description | Required |
|-----------|------------|---------|
| Format | How to format the command parameter using printf syntax. For example: "0x%0X" will display a parameter in hex. | Yes |

Example Usage:
{% highlight bash %}
FORMAT_STRING "0x%0X"
{% endhighlight %}

### UNITS

The UNITS keyword add units knowledge to a parameter.

| Parameter | Description | Required |
|-----------|------------|---------|
| Full Name | Full name of the units type. For example: Celcius | Yes |
| Abbreviated Name | Abbreviation for the units. For example: C | Yes |

Example Usage:
{% highlight bash %}
UNITS Celcius C
UNITS Kilometers KM
{% endhighlight %}

### MINIMUM_VALUE, MAXIMUM_VALUE, DEFAULT_VALUE, DESCRIPTION

These keywords allow you to override an existing value. This is useful for changing things in conjunction with SELECT_COMMAND and SELECT_PARAMETER.

| Parameter | Description | Required |
|-----------|------------|---------|
| Value | The new value to replace the previously defined value | Yes |

Example Usage:
{% highlight bash %}
SELECT_COMMAND COSMOS START_LOGGING
  SELECT_PARAMETER OPCODE
    MINIMUM_VALUE 1
    MAXIMUM_VALUE 1
    DEFAULT_VALUE 1
    DESCRIPTION "Opcode is the command identifier"
{% endhighlight %}

### STATE

The STATE keyword defines a key/value pair for the current command parameter. For example, you might define states for ON = 1 and OFF = 0. This allows the word ON to be used rather than the number 1 when sending the command parameter and allows for much greater clarity and less chance for user error.

| Parameter | Description | Required |
|-----------|------------|---------|
| Key | The state name | Yes |
| Value | The state value | Yes |
| HAZARDOUS | Keyword the indicates the state is hazardous. This will cause a popup to ask for user confirmation when sending this command. | No |
| Hazardous Description | Description about why this state is hazardous. | No |

Example Usage:
{% highlight bash %}
APPEND_PARAMETER ENABLE 32 UINT 0 1 0 "Enable setting"
  STATE FALSE 0
  STATE TRUE 1
APPEND_PARAMETER STRING 1024 STRING "NOOP" "String parameter"
  STATE "NOOP" "NOOP"
  STATE "ARM LASER" "ARM LASER" HAZARDOUS "Arming the laser is an eye safety hazard"
  STATE "FIRE LASER" "FIRE LASER" HAZARDOUS "WARNING! Laser will be fired!"
{% endhighlight %}

### WRITE_CONVERSION

The WRITE_CONVERSION keyword applies a conversion to the current command parameter. This conversion is implemented in a custom Ruby file which should be located in the target's lib folder and required by the target's target.txt file. See the documentation in <ac:link ac:anchor="TargetConfiguration"><ri:page ri:content-title="System Configuration" /></ac:link>. The class must require 'cosmos/conversions/conversion' and inherit from Conversion. It must implement the initialize method if it takes extra parameters and must always implement the call method. The conversion factor is applied to the value entered by the user before it is written into the binary command packet and sent.

| Parameter | Description | Required |
|-----------|------------|---------|
| Class file name | The file name which contains the Ruby class. The file name must be named after the class such that the class is a CamelCase version of the underscored file name. For example: 'the_great_conversion.rb' should contain 'class TheGreatConversion'. | Yes |
| Param X | Parameter #x. Additional parameter values for the conversion which are passed to the class constructor. | No |

Example Usage:
{% highlight bash %}
WRITE_CONVERSION the_great_conversion.rb 1000
{% endhighlight %}

the_great_conversion.rb:
{% highlight ruby %}
require 'cosmos/conversions/conversion'
module Cosmos
  class TheGreatConversion < Conversion
    def initialize(multiplier)
      super()
      @multiplier = multiplier
    end
    def call(value, packet, buffer)
      return value * multiplier
    end
  end
end
{% endhighlight %}

### POLY_WRITE_CONVERSION

The POLY_WRITE_CONVERSION keyword adds a polynomial conversion factor to the current command parameter. This conversion factor is applied to the value entered by the user before it is written into the binary command packet and sent.

| Parameter | Description |Required |
|-----------|------------|---------|
| C0 | Coefficient #0 | Yes |
| Cx | Coefficient #x. Additional coefficient values for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate. | No |

Example Usage:
{% highlight bash %}
POLY_WRITE_CONVERSION 10 0.5 0.25
{% endhighlight %}

### SEG_POLY_WRITE_CONVERSION

The SEG_POLY_WRITE_CONVERSION keyword adds a segmented polynomial conversion factor to the current command parameter. This conversion factor is applied to the value entered by the user before it is written into the binary command packet and sent.

| Parameter | Description | Required |
|-----------|------------|---------|
| Lower Bound | Defines the lower bound of the range of values that this segmented polynomial applies to. Is ignored for the segment with the smallest lower bound. | Yes |
| C0 | Coefficient #0 | Yes |
| Cx | Coefficient #x. Additional coefficient values for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate. | No |

Example Usage:
{% highlight bash %}
SEG_POLY_WRITE_CONVERSION 0 10 0.5 0.25 # Apply the conversion to all values < 50
SEG_POLY_WRITE_CONVERSION 50 11 0.5 0.275 # Apply the conversion to all values >= 50 and < 100
SEG_POLY_WRITE_CONVERSION 100 12 0.5 0.3 # Apply the conversion to all values >= 100
{% endhighlight %}

### GENERIC_WRITE_CONVERSION_START and GENERIC_WRITE_CONVERSION_END

**NOTE: Generic conversions are not a good long term solution.  Consider creating a conversion class and using WRITE_CONVERSION instead.  WRITE_CONVERSION is easier to debug and higher performance. **

The GENERIC_WRITE_CONVERSION_START keyword adds a generic conversion function to the current command parameter. This conversion factor is applied to the value entered by the user before it is written into the binary command packet and sent. The conversion is specified as ruby code that receives two implied parameters: 'value' which is the raw value being written, and 'packet' which is a reference to the command packet class (Note: referencing the packet as 'myself' is still supported for backwards compatibility). The last line of ruby code given should return the converted value. The GENERIC_WRITE_CONVERSION_END keyword specifies that all lines of ruby code for the conversion have been given.

Example Usage:
{% highlight bash %}
APPEND_PARAMETER ITEM1 32 UINT 0 0xFFFFFFFF 0
  GENERIC_WRITE_CONVERSION_START
    (value * 1.5).to_i # Convert the value by a scale factor
  GENERIC_WRITE_CONVERSION_END
{% endhighlight %}

Note: If you need to apply a conversion that depends on another parameter being set then special code must be added to check the other parameter's value. COSMOS processes the parameters as a Hash and the order or processing is NOT guaranteed. For example:

{% highlight ruby %}
COMMAND INST SETPOINT BIG_ENDIAN "Control Setpoint"
  ..
  APPEND_PARAMETER ZONE 8 UINT 1 10 1 "Heater zone"
    STATE ONE 1
    STATE TWO 2
  APPEND_PARAMETER SETPOINT 32 FLOAT 0 1000 0 "Setpoint"
    GENERIC_WRITE_CONVERSION_START
      result = nil
      case myself.given_values['ZONE'] # Access the zone value
      when 'ONE'
        result = value * 1
      when 'TWO'
        result = value * 2
      end
      return result
    GENERIC_WRITE_CONVERSION_END
{% endhighlight %}

### META

The META keyword stores metadata for the current command parameter that can be used by custom tools for various purposes (For example to store additional information needed to generate FSW header files).

| Parameter | Description | Required |
|-----------|------------|---------|
| Meta Name | Name of the metadata to store | Yes |
| Meta Values | One or more values to be stored for this Meta Name | No |

Example Usage:
{% highlight bash %}
META TEST "This parameter is for test purposes only"
{% endhighlight %}

## Example File

**Example File: &lt;COSMOSPATH&gt;/config/MY_TARGET/cmd_tlm/cmds.txt**

{% highlight bash %}
COMMAND MY_TARGET COLLECT_DATA BIG_ENDIAN "Commands my target to collect data"
  PARAMETER CCSDSVER 0 3 UINT 0 0 0 "CCSDS PRIMARY HEADER VERSION NUMBER"
  PARAMETER CCSDSTYPE 3 1 UINT 1 1 1 "CCSDS PRIMARY HEADER PACKET TYPE"
  PARAMETER CCSDSSHF 4 1 UINT 0 0 0 "CCSDS PRIMARY HEADER SECONDARY HEADER FLAG"
  ID_PARAMETER CCSDSAPID 5 11 UINT 0 2047 100 "CCSDS PRIMARY HEADER APPLICATION ID"
  PARAMETER CCSDSSEQFLAGS 16 2 UINT 3 3 3 "CCSDS PRIMARY HEADER SEQUENCE FLAGS"
  PARAMETER CCSDSSEQCNT 18 14 UINT 0 16383 0 "CCSDS PRIMARY HEADER SEQUENCE COUNT"
  PARAMETER CCSDSLENGTH 32 16 UINT 4 4 4 "CCSDS PRIMARY HEADER PACKET LENGTH"
  PARAMETER ANGLE 48 32 FLOAT -180.0 180.0 0.0 "ANGLE OF INSTRUMENT IN DEGREES"
    POLY_WRITE_CONVERSION 0 0.01745 0 0
  PARAMETER MODE 80 8 UINT 0 1 0 "DATA COLLECTION MODE"
    STATE NORMAL 0
    STATE DIAG 1

COMMAND MY_TARGET NOOP BIG_ENDIAN "Do Nothing"
  PARAMETER CCSDSVER 0 3 UINT 0 0 0 "CCSDS PRIMARY HEADER VERSION NUMBER"
  PARAMETER CCSDSTYPE 3 1 UINT 1 1 1 "CCSDS PRIMARY HEADER PACKET TYPE"
  PARAMETER CCSDSSHF 4 1 UINT 0 0 0 "CCSDS PRIMARY HEADER SECONDARY HEADER FLAG"
  ID_PARAMETER CCSDSAPID 5 11 UINT 0 2047 101 "CCSDS PRIMARY HEADER APPLICATION ID"
  PARAMETER CCSDSSEQFLAGS 16 2 UINT 3 3 3 "CCSDS PRIMARY HEADER SEQUENCE FLAGS"
  PARAMETER CCSDSSEQCNT 18 14 UINT 0 16383 0 "CCSDS PRIMARY HEADER SEQUENCE COUNT"
  PARAMETER CCSDSLENGTH 32 16 UINT 0 0 0 "CCSDS PRIMARY HEADER PACKET LENGTH"
  PARAMETER DUMMY 48 8 UINT 0 0 0 "DUMMY PARAMETER BECAUSE CCSDS REQUIRES 1 BYTE OF DATA"

COMMAND MY_TARGET SETTINGS BIG_ENDIAN "Set the Settings"
  PARAMETER CCSDSVER 0 3 UINT 0 0 0 "CCSDS PRIMARY HEADER VERSION NUMBER"
  PARAMETER CCSDSTYPE 3 1 UINT 1 1 1 "CCSDS PRIMARY HEADER PACKET TYPE"
  PARAMETER CCSDSSHF 4 1 UINT 0 0 0 "CCSDS PRIMARY HEADER SECONDARY HEADER FLAG"
  ID_PARAMETER CCSDSAPID 5 11 UINT 0 2047 102 "CCSDS PRIMARY HEADER APPLICATION ID"
  PARAMETER CCSDSSEQFLAGS 16 2 UINT 3 3 3 "CCSDS PRIMARY HEADER SEQUENCE FLAGS"
  PARAMETER CCSDSSEQCNT 18 14 UINT 0 16383 0 "CCSDS PRIMARY HEADER SEQUENCE COUNT"
  PARAMETER CCSDSLENGTH 32 16 UINT 0 0 0 "CCSDS PRIMARY HEADER PACKET LENGTH"
  MACRO_APPEND_START 1 5
    APPEND_PARAMETER SETTING 16 UINT 0 5 0 "Setting #x"
  MACRO_APPEND_END
{% endhighlight %}

## Telemetry Definition Files

Telemetry definition files define the telemetry packets that can be received and processed from COSMOS targets. One large file can be used to define the telemetry packets, or multiple files can be used at the user's discretion. Telemetry definition files are placed in the config/TARGET/cmd_tlm directory and are processed alphabetically. Therefore if you have some telemetry files that depend on others, e.g. they override or extend existing telemetry, they must be named last. Due to the way the [ASCII Table](http://www.asciitable.com/) is structured, files beginning with capital letters are processed before lower case letters. To force a file to be processed last either prepend it with 'z' or '~'.

## **Telemetry Keywords:**

### TELEMETRY

The TELEMETRY keyword designates the start of a new telemetry packet.

| Parameter | Description | Required |
|-----------|------------|---------|
| Target Name | Name of the target this command is associated with | Yes |
| Packet Name | Name of this telemetry packet. Also referred to as its mnemonic. Must be unique to telemetry packets in this target. Ideally will be as short and clear as possible. | Yes |
| BIG_ENDIAN or LITTLE_ENDIAN | Indicates if the data in this packet is in Big Endian or Little Endian format. | Yes |
| Description | Description of this telemetry packet. Must be enclosed with "" | No |

Example Usage:
{% highlight bash %}
TELEMETRY COSMOS VERSION BIG_ENDIAN "Version information"
{% endhighlight %}

### SELECT_TELEMETRY

The SELECT_TELEMETRY keyword selects an existing telemetry packet for editing.

| Parameter | Description | Required |
|-----------|------------|---------|
| Target Name | Name of the target this telemetry packet is associated with | Yes |
| Packet Name | Name of this telemetry packet | Yes |

Example Usage:
{% highlight bash %}
SELECT_TELEMETRY COSMOS VERSION
{% endhighlight %}

### LIMITS_GROUP

The LIMITS_GROUP keyword defines a related group of limits that can be enabled and disabled together. It can be used to group related limits as a subsystem that can be enabled or disabled as that particular subsystem is powered (for example). To enable a group call the enable_limits_group("NAME") method in Script Runner. To disable a group call the disable_limits_group("NAME") in Script Runner. Items can belong to multiple groups but the last enabled or disabled group "wins". For example, if an item belongs to GROUP1 and GROUP2 and you first enable GROUP1 and then disable GROUP2 the item will be disabled. If you then enable GROUP1 again it will be enabled.

| Parameter | Description | Required |
|-----------|------------|---------|
| Group Name | Name of the limits group | Yes |

### LIMITS_GROUP_ITEM

The LIMITS_GROUP_ITEM keyword adds the specified telemetry item to the last defined LIMITS_GROUP.

| Parameter | Description | Required |
|-----------|------------|---------|
| Target Name | Name of the target | Yes |
| Packet Name | Name of the packet | Yes |
| Item Name | Name of the telemetry item to add to the group | Yes |

Example Usage:
{% highlight bash %}
LIMITS_GROUP SUBSYSTEM
  LIMITS_GROUP_ITEM INST HEALTH_STATUS TEMP1
  LIMITS_GROUP_ITEM INST HEALTH_STATUS TEMP2
  LIMITS_GROUP_ITEM INST HEALTH_STATUS TEMP3
{% endhighlight %}

This information is typically kept in a separate configuration file in the config/TARGET/cmd_tlm folder named limits_groups.txt. If you want to configure multiple target items in a particular group you should put this information in the config/SYSTEM/cmd_tlm/limits_groups.txt file. The SYSTEM target is processed last and contains information that crosses target boundaries.

## Telemetry Modifiers

The following keywords modify a telemetry packet and are only applicable after the TELEMETRY or SELECT_TELEMETRY keywords. They are typically indented within the definition file to show ownership to the previously defined telemetry packet.

### ITEM

The ITEM keyword defines a telemetry item in the current telemetry packet.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the telemetry item. Also referred to as its mnemonic. Must be unique within the packet. | Yes |
| Bit Offset | Bit offset into the telemetry packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters. | Yes |
| Bit Size | Bit size of this telemetry item. Zero or Negative values may be used to indicate that a string fills the packet up to the offset from the end of the packet specified by this value. If Bit Offset = 0 and Bit Size = 0 then this is a derived item and the Data Type must be set to 'DERIVED'. | Yes |
| Data Type | Data Type of this telemetry item. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0. | Yes |
| Description | Description for this telemetry item. Must be enclosed with "". | No |

Example Usage:
{% highlight bash %}
ITEM PKTID 112 16 UINT "Packet ID"
{% endhighlight %}

### APPEND_ITEM

The APPEND_ITEM keyword appends a new telemetry item to the end of the current telemetry packet. Parameter details are the same as the ITEM keyword except that Bit Offset is not used. This is the preferred way to declare items as it allows for adding and removing items without having to recalculate bit offsets for all other items.

Example Usage:
{% highlight bash %}
APPEND_ITEM PKTID 16 UINT "Packet ID"
{% endhighlight %}

### ID_ITEM

Much like the ITEM keyword, the ID_ITEM keyword defines a telemetry item in the current telemetry packet. However, ID_ITEMs are used to identify a telemetry packet from a binary array of data. The COSMOS Commmand and Telemetry Server identifies packets after they are received by an interface. A telemetry packet may have one or more ID_ITEMS, all of which must match the binary data for the telemetry packet to be identified.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the telemetry item. Also referred to as its mnemonic. Must be unique within the packet. | Yes |
| Bit Offset | Bit offset into the telemetry packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters. | Yes |
| Bit Size | Bit size of this telemetry item. Zero or Negative values may be used to indicate that a string fills the packet up to the offset from the end of the packet specified by this value. If Bit Offset = 0 and Bit Size = 0 then this is a derived item and the Data Type must be set to 'DERIVED'. | Yes |
| Data Type | Data Type of this telemetry item. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0. | Yes |
| ID Value | The value of this telemetry item that uniquely identifies this telemetry packet | Yes |
| Description | Description for this telemetry item. Must be enclosed with "". | No |

Example Usage:
{% highlight bash %}
ID_ITEM PKTID 112 16 UINT 1 "Packet ID which must be 1"
{% endhighlight %}

### APPEND_ID_ITEM

The APPEND_ID_ITEM keyword appends a new id telemetry item to the end of the current telemetry packet. Parameter details are the same as the ID_ITEM keyword except that Bit Offset is not used.

Example Usage:
{% highlight bash %}
APPEND_ID_ITEM PKTID 16 UINT 1 "Packet ID which must be 1"
{% endhighlight %}

### ARRAY_ITEM

The ARRAY_ITEM keyword defines a telemetry item in the current telemetry packet that is an array.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the telemetry item. Also referred to as its mnemonic. Must be unique within the packet. | Yes |
| Bit Offset | Bit offset into the telemetry packet of the Most Significant Bit of this parameter. May be negative to indicate on offset from the end of the packet. Always use a bit offset of 0 for derived parameters. | Yes |
| Bit Size of Each Item | Bit size of each array item. Must be greater than or equal to 0. If Bit Offset = 0 and Bit Size = 0 then this is a derived parameter and the Data Type must be set to 'DERIVED'. | Yes |
| Data Type of Each Item | Data Type of each array item. Possible types: INT = Integer, UINT = Unsigned Integer, FLOAT = IEEE Floating point data, STRING = Character string data, BLOCK = Non-Ascii Data Block, DERIVED = Bit Offset and Bit Size of 0. | Yes |
| Total Bit Size of Array | Total Bit Size of the Array. Zero or Negative values may be used to indicate the array fills the packet up to the offset from the end of the packet specified by this value. | Yes |
| Description | Description for this parameter. Must be enclosed with "". | No |

Example Usage:
{% highlight bash %}
ARRAY_ITEM ARRAY 64 32 FLOAT 320 "Array of 10 floats"
{% endhighlight %}

### APPEND_ARRAY_ITEM

The APPEND_ARRAY_ITEM keyword appends a new array telemetry item to the end of the current telemetry packet. Parameter details are the same as the ARRAY_ITEM keyword except that Bit Offset is not used.

Example Usage:
{% highlight bash %}
APPEND_ARRAY_ITEM ARRAY 32 FLOAT 320 "Array of 10 floats"
{% endhighlight %}

### SELECT_ITEM

The SELECT_ITEM keyword selects an existing telemetry item for editing in the current telemetry packet.

| Parameter | Description | Required |
|-----------|------------|---------|
| Name | Name of the telemetry item to select for modification | Yes |

Example Usage:
{% highlight bash %}
SELECT_TELEMETRY COSMOS VERSION
  SELECT_ITEM RUBY
{% endhighlight %}

### MACRO_APPEND_START and MACRO_APPEND_END

The MACRO_APPEND_START keyword is used to create a list of telemetry items which are appended to the current telemetry packet. Each of these items will be repeated with a number appended to their names to form a list of items with a unique mnemonic for each.

| Parameter | Description | Required |
|-----------|------------|---------|
| First Number in Range | First value that will be appended to the telemetry item mnemonic | Yes |
| Last Number in Range | Last number that will be appended to the telemetry item mnemonic | Yes |
| Format String | An optional format string that defaults to "%s%d". Where the %s represents the constant portion of the items mnemonic and the %d represents the number in the range that is appended. For example, with a range of 1 to 2 and two items named VALUE and DATA, the format string "%s_%d" would create the mnemonics VALUE_1, DATA_1, VALUE_2, and DATA_2. | No |

Example Usage:
{% highlight bash %}
MACRO_APPEND_START 1 2 "%s_%d"
  APPEND_ITEM VALUE 16 UINT "Value"
  APPEND_ITEM DATA 16 UINT "Data"
MACRO_APPEND_END
{% endhighlight %}

This results in a telemtry packet with the following mnemonics: VALUE_1, DATA_1, VALUE_2, and DATA_2. Note that due to the dynamic nature of this keyword you must use the APPEND variation of the ITEM keywords.

### META

The META keyword stores metadata for the current telemetry packet that can be used by custom tools for various purposes (For example to store additional information needed to generate FSW header files).

| Parameter | Description | Required |
|-----------|------------|---------|
| Meta Name | Name of the metadata to store | Yes |
| Meta Values | One or more values to be stored for this Meta Name | No |

Example Usage:
{% highlight bash %}
META FSW_TYPE "struct tlm_packet"
{% endhighlight %}

### PROCESSOR

The PROCESSOR keyword defines a processor class that execute code every time a packet is received.

| Parameter | Description | Required |
|-----------|------------|---------|
| Processor Name | The name of the processor | Yes |
| Processor Class Filename | Name of the Ruby file which implements the processor. This file should be in the config/TARGET/lib directory so it can be found by COSMOS. | Yes |
| Processor Specific Options | Variable length number of options that will be passed to the class constructor. | Processor Specific |

Example Usage:
{% highlight bash %}
PROCESSOR TEMP1HIGH watermark_processor.rb TEMP1
{% endhighlight %}

### ALLOW_SHORT

Allows the telemetry packet to be received with a data portion that is smaller than the defined size without warnings.  Any extra space in the packet will be filled in with zeros by COSMOS.

## Item Modifiers

The following keywords modify a telemetry item and are only applicable after the various ITEM keywords as defined above. They are typically indented within the definition file to show ownership to the previously defined telemetry item.

### FORMAT_STRING

The FORMAT_STRING keyword adds printf style formatting to a telemetry item.

| Parameter | Description | Required |
|-----------|------------|---------|
| Format | How to format the command parameter using printf syntax. For example: "0x%0X" will display an item in hex. | Yes |

Example Usage:
{% highlight bash %}
FORMAT_STRING "0x%0X"
{% endhighlight %}

### UNITS

The UNITS keyword add units knowledge to a telemetry item.

| Parameter | Description | Required |
|-----------|------------|---------|
| Full Name | Full name of the units type. For example: Celcius | Yes |
| Abbreviated Name | Abbreviation for the units. For example: C | Yes |

Example Usage:
{% highlight bash %}
UNITS Celcius C
UNITS Kilometers KM
{% endhighlight %}

### DESCRIPTION

The DESCRIPTION keywords allow you to override an existing description. This is useful for changing things in conjunction with SELECT_TELEMETRY and SELECT_ITEM.

| Parameter | Description | Required |
|-----------|------------|---------|
| Description | The new description | Yes |

Example Usage:
{% highlight bash %}
SELECT_TELEMETRY COSMOS VERSION
  SELECT_PARAMETER RUBY
    DESCRIPTION "The Ruby version"
{% endhighlight %}

### STATE

The STATE keyword defines a key/value pair for the current telemetry item. For example, you might define states for ON = 1 and OFF = 0. This allows the word ON to be used rather than the number 1 when checking the telemetry item and allows for much greater clarity and less chance for user error.

| Parameter | Description | Required |
|-----------|------------|---------|
| Key | The state name | Yes |
| Value | The state value | Yes |
| Color | The color the state should be displayed as. Default is black. Choices are GREEN, YELLOW, RED. | No |

Example Usage:
{% highlight bash %}
APPEND_ITEM ENABLE 32 UINT "Enable setting"
  STATE FALSE 0
  STATE TRUE 1
APPEND_ITEM STRING 1024 STRING "String"
  STATE "NOOP" "NOOP" GREEN
  STATE "ARM LASER" "ARM LASER" YELLOW
  STATE "FIRE LASER" "FIRE LASER" RED
{% endhighlight %}

### READ_CONVERSION

The READ_CONVERSION keyword applies a conversion to the current telemetry item. This conversion is implemented in a custom Ruby file which should be located in the target's lib folder and required by the target's target.txt file. See the documentation in <ac:link ac:anchor="TargetConfiguration"><ri:page ri:content-title="System Configuration" /></ac:link>. The class must require 'cosmos/conversions/conversion' and inherit from Conversion. It must implement the initialize method if it takes extra parameters and must always implement the call method. This conversion factor is applied to the raw value in the telemetry packet before it is displayed to the user. The user still has the ability to see the raw unconverted value in a details dialog.

| Parameter | Description | Required |
|-----------|------------|---------|
| Class file name | The file name which contains the Ruby class. The file name must be named after the class such that the class is a CamelCase version of the underscored file name. For example: 'the_great_conversion.rb' should contain 'class TheGreatConversion'. | Yes |
| Param X | Parameter #x. Additional parameter values for the conversion which are passed to the class constructor. | No |

Example Usage:
{% highlight bash %}
READ_CONVERSION the_great_conversion.rb 1000
{% endhighlight %}

the_great_conversion.rb:
{% highlight ruby %}
require 'cosmos/conversions/conversion'
module Cosmos
  class TheGreatConversion < Conversion
    def initialize(multiplier)
      super()
      @multiplier = multiplier
    end
    def call(value, packet, buffer)
      return value * multiplier
    end
  end
end
{% endhighlight %}

### POLY_READ_CONVERSION

The POLY_READ_CONVERSION keyword adds a polynomial conversion factor to the current telemetry item. This conversion factor is applied to the raw value in the telemetry packet before it is displayed to the user. The user still has the ability to see the raw unconverted value in a details dialog.

| Parameter | Description | Required |
|-----------|------------|---------|
| C0 | Coefficient #0 | Yes |
| Cx | Coefficient #x. Additional coefficient values for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate. | No |

Example Usage:
{% highlight bash %}
POLY_READ_CONVERSION 10 0.5 0.25
{% endhighlight %}

### SEG_POLY_READ_CONVERSION

The SEG_POLY_READ_CONVERSION keyword adds a segmented polynomial conversion factor to the current telemetry item. This conversion factor is applied to the raw value in the telemetry packet before it is displayed to the user. The user still has the ability to see the raw unconverted value in a details dialog.

| Parameter | Description | Required |
|-----------|------------|---------|
| Lower Bound | Defines the lower bound of the range of values that this segmented polynomial applies to. Is ignored for the segment with the smallest lower bound. | Yes |
| C0 | Coefficient #0 | Yes |
| Cx | Coefficient #x. Additional coefficient values for the conversion. Any order polynomial conversion may be used so the value of 'x' will vary with the order of the polynomial. Note that larger order polynomials take longer to process than shorter order polynomials, but are sometimes more accurate. | No |

Example Usage:
{% highlight bash %}
SEG_POLY_READ_CONVERSION 0 10 0.5 0.25 # Apply the conversion to all values < 50
SEG_POLY_READ_CONVERSION 50 11 0.5 0.275 # Apply the conversion to all values >= 50 and < 100
SEG_POLY_READ_CONVERSION 100 12 0.5 0.3 # Apply the conversion to all values >= 100
{% endhighlight %}

### GENERIC_READ_CONVERSION_START and GENERIC_READ_CONVERSION_END

**NOTE: Generic conversions are not a good long term solution.  Consider creating a conversion class and using READ_CONVERSION instead.  READ_CONVERSION is easier to debug and higher performance. **

The GENERIC_READ_CONVERSION_START keyword adds a generic conversion function to the current telemetry item. This conversion factor is applied to the raw value in the telemetry packet before it is displayed to the user. The user still has the ability to see the raw unconverted value in a details dialog. The conversion is specified as ruby code that receives two implied parameters: 'value' which is the raw value being read, and 'myself' which is a reference to the telemetry packet class. The last line of ruby code given should return the converted value. The GENERIC_READ_CONVERSION_END keyword specifies that all lines of ruby code for the conversion have been given.

Example Usage:
{% highlight ruby %}
APPEND_ITEM ITEM1 32 UINT
  GENERIC_READ_CONVERSION_START
    value * 1.5  # Convert the value by a scale factor
  GENERIC_READ_CONVERSION_END
{% endhighlight %}

 You can also create a conversion that depends on another parameter For example:

{% highlight ruby %}
TELEMETRY INST HEALTH_STATUS BIG_ENDIAN "Health and status"
  ..
  APPEND_ITEM ZONE 8 UINT "Heater zone"
    STATE ONE 1
    STATE TWO 2
  ITEM ZONE_CONV 0 0 DERIVED
    GENERIC_READ_CONVERSION_START
      result = myself.read('ZONE', :RAW) # Access the raw zone value
      return result * 1.5
    GENERIC_READ_CONVERSION_END
{% endhighlight %}

### LIMITS

The LIMITS keywords defines a set of limits for a telemetry item. If limits are violated a message is printed in the Command and Telemetry Server to indicate an item went out of limits. Other tools also use this information to update displays with different colored telemetry items or other useful information. The concept of "limits sets" is defined to allow for different limits values in different environments. For example, you might want tighter or looser limits on telemetry if your environment changes such as during thermal vacuum testing.

| Parameter | Description | Required |
|-----------|------------|---------|
| Limits Set | Name of the limits set. If you have no unique limits sets use the keyword DEFAULT. | Yes |
| Persistence | Number of consecutive times the telemetry item must be within a different limits range before changing limits state. | Yes |
| ENABLED or DISABLED | Whether limits monitoring for this telemetry item is initially enabled or disabled. | Yes |
| Red Low Limit | If the telemetry value is less than or equal to this value a Red Low condition will be detected. | Yes |
| Yellow Low Limit | If the telemetry value is less than or equal to this value, but greater than the Red Low Limit, a Yellow Low condition will be detected. | Yes |
| Yellow High Limit | If the telemetry value is greater than or equal to this value, but less than the Red High Limit, a Yellow High condition will be detected. | Yes |
| Red High Limit | If the telemetry value is greater than or equal to this value a Red High condition will be detected. | Yes |
| Green Low Limit | Setting the Green Low and Green High limits defines an "operational limit" which is colored blue by COSMOS. This allows for a distinct desired operational range which is narrower than the green safety limit. If the telemetry value is greater than or equal to this value, but less than the Green High Limit, a Blue operational condition will be detected. | No |
| Green High Limit | See above. If the telemetry value is less than or equal to this value, but greater than the Green Low Limit, a Blue operational condition will be detected. | No |

Example Usage:
{% highlight bash %}
LIMITS DEFAULT 3 ENABLED -80.0 -70.0 60.0 80.0 -20.0 20.0
LIMITS TVAC 3 ENABLED -80.0 -30.0 30.0 80.0
{% endhighlight %}

### LIMITS_RESPONSE

The LIMITS_RESPONSE keyword defines a response class that will be called when the limits state of the current item changes.

| Parameter | Description | Required |
|-----------|------------|---------|
| Response Class Filename | Name of the Ruby file which implements the limits response. This file should be in the config/TARGET/lib directory so it can be found by COSMOS. | Yes |
| Response Specific Options | Variable length number of options that will be passed to the class constructor. | Response Specific |

Example Usage:
{% highlight bash %}
LIMITS_RESPONSE example_limits_response.rb 10
{% endhighlight %}

### META

The META keyword stores metadata for the current item that can be used by custom tools for various purposes (For example to store additional information needed to generate FSW header files).

| Parameter | Description | Required |
|-----------|------------|---------|
| Meta Name | Name of the metadata to store | Yes
| Meta Values | One or more values to be stored for this Meta Name | No |

Example Usage:
{% highlight bash %}
META TEST "This item is for test purposes only"
{% endhighlight %}

## Example File

**Example File: &lt;COSMOSPATH&gt;/config/MY_TARGET/cmd_tlm/tlm.txt**

{% highlight bash %}
TELEMETRY MY_TARGET HS BIG_ENDIAN "Health and Status for My Target"
  ITEM CCSDSVER 0 3 UINT "CCSDS PACKET VERSION NUMBER (SEE CCSDS 133.0-B-1)"
  ITEM CCSDSTYPE 3 1 UINT "CCSDS PACKET TYPE (COMMAND OR TELEMETRY)"
    STATE TLM 0
    STATE CMD 1
  ITEM CCSDSSHF 4 1 UINT "CCSDS SECONDARY HEADER FLAG"
    STATE FALSE 0
    STATE TRUE 1
  ID_ITEM CCSDSAPID 5 11 UINT 102 "CCSDS APPLICATION PROCESS ID"
  ITEM CCSDSSEQFLAGS 16 2 UINT "CCSDS SEQUENCE FLAGS"
    STATE FIRST 0
    STATE CONT 1
    STATE LAST 2
    STATE NOGROUP 3
  ITEM CCSDSSEQCNT 18 14 UINT "CCSDS PACKET SEQUENCE COUNT"
  ITEM CCSDSLENGTH 32 16 UINT "CCSDS PACKET DATA LENGTH"
  ITEM CCSDSDAY 48 16 UINT "DAYS SINCE EPOCH (JANUARY 1ST, 1958, MIDNIGHT)"
  ITEM CCSDSMSOD 64 32 UINT "MILLISECONDS OF DAY (0 - 86399999)"
  ITEM CCSDSUSOMS 96 16 UINT "MICROSECONDS OF MILLISECOND (0-999)"
  ITEM ANGLEDEG 112 16 INT "Instrument Angle in Degrees"
    POLY_READ_CONVERSION 0 57.295
  ITEM MODE 128 8 UINT "Instrument Mode"
    STATE NORMAL 0 GREEN
    STATE DIAG 1 YELLOW
  MACRO_APPEND_START 1 5
    APPEND_ITEM SETTING 16 UINT "SETTING #x"
  MACRO_APPEND_END
  ITEM TIMESECONDS 0 0 FLOAT "DERIVED TIME SINCE EPOCH IN SECONDS"
    GENERIC_READ_CONVERSION_START
      ((myself.ccsdsday.to_f * 86400.0) + (myself.ccsdsmsod.to_f / 1000.0) + (myself.ccsdsusoms.to_f / 1000000.0))
    GENERIC_READ_CONVERSION_END
  ITEM TIMEFORMATTED 0 0 STRING "DERIVED TIME SINCE EPOCH AS A FORMATTED STRING"
    GENERIC_READ_CONVERSION_START
      require 'time_util'
      time = TimeUtil.cds_to_mdy(myself.ccsdsday, myself.ccsdsmsod, myself.ccsdsusoms)
      sprintf('%04u/%02u/%02u %02u:%02u:%02u.%06u', time[0], time[1], time[2], time[3], time[4], time[5], time[6])
    GENERIC_READ_CONVERSION_END
{% endhighlight %}
