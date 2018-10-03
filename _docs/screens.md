---
layout: docs
title: Telemetry Screens
permalink: /docs/screens/
toc: true
---
This document provides the information necessary to generate and use COSMOS Telemetry Screens, which are displayed by the COSMOS Telemetry Viewer application.

<div style="clear:both;"></div>

## Definitions

| Name | Definition |
| ----- | --------|
| Widget | A widget is a graphical element on a COSMOS telemetry screen. It could display text, graph data, provide a button, or perform any other display/user input task. |
| Screen | A screen is a single window that contains any number of widgets which are organized and layed-out in a useful fashion. |
| Screen Definition File | A screen definition file is an ASCII file that tells COSMOS Telemetry Viewer how to draw a screen. It is made up of a series of keyword/parameter lines that define the telemetry points that are displayed on the screen and how to display them. |

## Telemetry Viewer Configuration
Two different types of configuration files are used to configure the COSMOS Telemetry Viewer; the screen definition files and a configuration file that lets the tool know what screens are available and how they are organized.

## Telemetry Screen Definition Files
Telemetry screen definition files define the the contents of telemetry screens. They take the general form of a SCREEN keyword followed by a series of widget keywords that define the telemetry screen. Screen definition files specific to a particular target go in that targets configuration folder. For example: config/targets/COSMOS/screens/version.txt. Screen definition files that combine telemetry from multiple targets typically go in the system target's screens folder. For example: config/targets/SYSTEM/screens/overall.txt.

## Keywords:

### SCREEN
The SCREEN keyword is the first keyword in any telemetry screen definition. It defines the name of the screen and parameters that affect the screen overall.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Width	| Width in pixels or AUTO to let Telemetry Viewer automatically layout the screen | Yes |
| Height | Height in pixels or AUTO to let Telemetry Viewer automatically layout the screen | Yes |
| Polling Period | Number of seconds between screen updates | Yes |
| Fixed | Force the window to be fixed size and not user resizeable | No |

Example Usage:
{% highlight bash %}
SCREEN AUTO AUTO 1.0 FIXED
{% endhighlight %}

### END
The END keyword is used to indicate the close of a layout widget. For example a VERTICALBOX keyword must be matched with an END keyword to indicate where the VERTICALBOX ends.

### STAY_ON_TOP
The STAY_ON_TOP keyword is used to force the screen to the front of the display stack. This forces the window to stay above ALL other windows including other applications not associated with COSMOS.

### GLOBAL_SETTING
The GLOBAL_SETTING keyword is used to apply a widget setting to allow widgets of a certain type.  (See SETTING)

| Parameter | Description | Required |
|-----------|-------------|----------|
| Widget Class Name | The name of the class of widgets that this setting will be applied to. For example: LABEL	| Yes |
| Setting Name | Widget specific setting name | Yes |
| Setting Value(s) | Widget specific value(s) to set | Varies |

Example Usage:
{% highlight bash %}
GLOBAL_SETTING LABELVALUELIMITSBAR COLORBLIND TRUE
{% endhighlight %}

### GLOBAL_SUBSETTING
The GLOBAL_SUBSETTING keyword is used to apply a widget subsetting to allow widgets of a certain type.  (See SUBSETTING)

| Parameter | Description | Required |
|-----------|-------------|----------|
| Widget Class Name | The name of the class of widgets that this setting will be applied to. For example: LABEL	| Yes |
| Subwidget Index | Index to the desired subwidget or 'ALL' | Yes |
| Setting Name | Widget specific setting name | Yes |
| Setting Value(s) | Widget specific value(s) to set | Varies |

Example Usage:
{% highlight bash %}
GLOBAL_SUBSETTING LABELVALUELIMITSBAR 1 COLORBLIND TRUE
GLOBAL_SUBSETTING LABELVALUELIMITSBAR 0:0 TEXTCOLOR white # Set all text color to white for labelvaluelimitsbars
{% endhighlight %}

### SETTING
The SETTING keyword is used to apply a widget setting to the widget that was specified immediately before it.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Setting Name | Widget specific setting name | Yes |
| Setting Value(s) | Widget specific value to set | Varies |

Example Usage:
{% highlight bash %}
VERTICALBOX
  LABEL ... # Various other widgets
END
SETTING BACKCOLOR 163 185 163 # RGB color for the box background
{% endhighlight %}

### SUBSETTING
The SUBSETTING keyword is used to apply a widget subsetting to the widget that was specified immediately before it. Subsettings are only valid for widgets that are made up of more than one subwidget.  For example, LABELVALUE is made up of a LABEL at subwidget index 0 and a VALUE at subwidget index 1.  This allows for passing settings to specific subwidgets. Some widgets are made up of multiple subwidgets, e.g. LABELVALUELIMITSBAR. To set the label text color, pass '0:0' as the Subwidget Index to first index the LABELVALUE and then to the LABEL.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Subwidget Index | Index to the desired subwidget or 'ALL' | Yes |
| Setting Name | Widget specific setting name | Yes |
| Setting Value(s) | Widget specific value to set | Varies |

Example Usage:
{% highlight bash %}
VERTICALBOX
  LABELVALUE ...
    SUBSETTING 0 TEXTCOLOR blue # Change only the label's color
  LABELVALUELIMITSBAR ...
    SUBSETTING 0:0 TEXTCOLOR white # Change the label's text color to white
END
{% endhighlight %}

### NAMED_WIDGET
The NAMED_WIDGET keyword is used to give a name to a widget that allows it to be accessed from other widgets using the get_named_widget method of Cosmos::Screen. Note that get_named_widget returns the widget itself and thus must be operated on using methods native to that widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Widget Name | The unique name applied to the following widget instance. Names must be unique per screen. | Yes |
| Widget Type | One of the widget types listed in Widget Descriptions | Yes |
| Widget Parameters | The unique parameters for the given widget type | Yes |

Example Usage:
{% highlight bash %}
NAMED_WIDGET heading TITLE "Main Heading"
BUTTON "Push" 'puts get_named_widget("heading").text'
{% endhighlight %}

### WIDGETNAME
All other keywords in a telemetry screen definition define the name of a widget and its unique parameters. These aren't really keywords at all and widgets can have any name besides the real keywords listed above. Whenever a keyword is encountered that is unrecognized, it is assumed that a file of the form widgetname_widget.rb exists, and contains a class called WidgetnameWidget. Because of this convention, new widgets can be added to the system without any change to the telemetry screen definition format Please see the Widget Descriptions section below for the details on all widgets supplied with the COSMOS core system.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Widget Type | One of the widget types listed in Widget Descriptions | Yes |
| Widget Parameters | The unique parameters for the given widget type | Yes |

Example Usage: See the Example File

## Example File

Example File: <Cosmos::USERPATH>/config/targets/<TARGET>/myscreen.txt

{% highlight bash %}
SCREEN AUTO AUTO 0.5
GLOBAL_SETTING LABELVALUELIMITSBAR COLORBLIND TRUE
VERTICAL
  TITLE "Instrument Health and Status"
    SETTING BACKCOLOR 162 181 205
    SETTING TEXTCOLOR black
  VERTICALBOX
    SECTIONHEADER "General Telemetry"
    BUTTON 'Start Collect' 'target_name = get_target_name("INST"); cmd("#{target_name} COLLECT with TYPE NORMAL, DURATION 5")'
    SETTING BACKCOLOR 54 95 58
    SETTING TEXTCOLOR white
    FORMATVALUE INST HEALTH_STATUS COLLECTS "0x%08X"
    LABELVALUE INST HEALTH_STATUS COLLECT_TYPE
    LABELVALUE INST HEALTH_STATUS DURATION
    LABELVALUE INST HEALTH_STATUS ASCIICMD WITH_UNITS 30
  END
  SETTING BACKCOLOR 163 185 163
  VERTICALBOX
    SECTIONHEADER "Temperatures"
    LABELTRENDLIMITSBAR INST HEALTH_STATUS TEMP1 WITH_UNITS 5
    LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP2
    LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP3
    LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP4
    SETTING GRAY_TOLERANCE 0.1
  END
  SETTING BACKCOLOR 203 173 158
  VERTICALBOX
    SECTIONHEADER "Ground Station"
    LABELVALUE INST HEALTH_STATUS GROUND1STATUS
    LABELVALUE INST HEALTH_STATUS GROUND2STATUS
  END
  VERTICALBOX
    LABELVALUE INST HEALTH_STATUS TIMEFORMATTED WITH_UNITS 30
    SCREENSHOTBUTTON
  END
  SETTING BACKCOLOR 207 171 169
END
SETTING BACKCOLOR 162 181 205
{% endhighlight %}

---

## Telemetry Viewer Settings Files
A telemetry viewer settings file tells telemetry viewer what screens exist and how they should be categorized. The default setting files is called tlm_viewer.txt and is located in config/tools/tlm_viewer/tlm_viewer.txt.

## Keywords:

### AUTO_TARGETS
The AUTO_TARGETS keyword tells Telemetry Viewer to add all the screens defined in the screens directory of each target folder in the config/targets directory. Screens are grouped by target name in the display. For example: all the screens defined in config/targets/COSMOS/screens will be added to a single drop down selection labeled COSMOS.

Example Usage:
{% highlight bash %}
AUTO_TARGETS
{% endhighlight %}

### AUTO_TARGET
The AUTO_TARGET keyword tells Telemetry Viewer to add all the screens defined in the screens directory of the specified target folder in the config/targets directory. Screens are grouped by target name in the display. For example: all the screens defined in config/targets/COSMOS/screens will be added to a single drop down selection labeled COSMOS. If AUTO_TARGETS is used this keyword does nothing.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Name of the target directory to look for screens. | Yes |

Example Usage:
{% highlight bash %}
AUTO_TARGET COSMOS
{% endhighlight %}

### NEW_COLUMN
The NEW_COLUMN keywords creates a new column of drop down selections in Telemetry Viewer. All the AUTO_TARGET or SCREEN keywords after this keyword will be added to a new column in the GUI.

### TARGET
The TARGET keyword is used to call out individual screens within a targets screen directory. It is used in conjunction with the SCREEN keyword.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Name | Name of the target directory to look for screens. | Yes |

Example Usage:
{% highlight bash %}
TARGET COSMOS
{% endhighlight %}

### SCREEN
The SCREEN keyword adds the specified screen from the specified target. It must follow the TARGET keyword and is typically indented to show ownership to the target.

| Parameter | Description | Required |
|-----------|-------------|----------|
| File Name | Name of the file containing the telemetry screen definition. The filename will be upcased and used in the drop down selection. | Yes |
| X Position | Position in pixels to draw the left edge of the screen on the display. If not supplied the screen will be centered. If supplied, the Y position must also be supplied. | No |
| Y Position | Position in pixels to draw the top edge of the screen on the display. If not supplied the screen will be centered. If supplied, the X position must also be supplied. | No |

Example Usage:
{% highlight bash %}
TARGET COSMOS
  SCREEN version.txt 50 50
{% endhighlight %}

### GROUP
The GROUP keyword is used to create a new drop down group in the Tlm Viewer application.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Group Name | Label to display in front of the group drop down. | Yes |

Example Usage:
{% highlight bash %}
GROUP "Special Ops"
{% endhighlight %}

### GROUP_SCREEN
The GROUP_SCREEN keyword is used to add a screen to a previously defined group. It must follow the GROUP keyword.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Name of the target where the screen is defined | Yes |
| File Name | Name of the file containing the telemetry screen definition. The filename will be upcased and used in the drop down selection. | Yes |
| X Position | Position in pixels to draw the left edge of the screen on the display. If not supplied the screen will be centered. If supplied, the Y position must also be supplied. | No |
| Y Position | Position in pixels to draw the top edge of the screen on the display. If not supplied the screen will be centered. If supplied, the X position must also be supplied. | No |

Example Usage:
{% highlight bash %}
GROUP "Special Ops"
  GROUP_SCREEN SYSTEM status.txt
{% endhighlight %}

### SHOW_ON_STARTUP
The SHOW_ON_STARTUP keyword causes the previously defined SCREEN to be automatically displayed when Telemetry Viewer starts. It must be preceeded by the SCREEN or GROUP_SCREEN keyword.

### ADD_SHOW_ON_STARTUP
The ADD_SHOW_ON_STARTUP keyword adds show on startup to any screen that has already been defined.  This is useful for adding show on startup to screens defined with AUTO_TARGETS.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Target Name of the screen | Yes |
| Screen Name | Base Name of the screen. This is equal to the screens filename with the .txt extension. | Yes |
| X Position | Position in pixels to draw the left edge of the screen on the display. If not supplied the screen will be centered. If supplied, the Y position must also be supplied. | No |
| Y Position | Position in pixels to draw the top edge of the screen on the display. If not supplied the screen will be centered. If supplied, the X position must also be supplied. | No |

Example Usage:
{% highlight bash %}
ADD_SHOW_ON_STARTUP INST HS 500 300
ADD_SHOW_ON_STARTUP INST ADCS
{% endhighlight %}

## Example File
Example File: <Cosmos::USERPATH>/config/tools/tlm_viewer/tlm_viewer.txt

{% highlight bash %}
TARGET INST
  SCREEN "adcs.txt"
  SCREEN "array.txt"
TARGET INST2
  SCREEN "commanding.txt" 898 317
    SHOW_ON_STARTUP
  SCREEN "hs.txt"
TARGET COSMOS
  SCREEN "version.txt"
GROUP "My group"
  GROUP_SCREEN SYSTEM "status.txt"
  GROUP_SCREEN INST "hs.txt"
  GROUP_SCREEN INST2 "hs.txt"
{% endhighlight %}

---

## Widget Descriptions
This section describes the usage of all the telemetry screen widgets that are provided by the core COSMOS system.

## Layout Widgets
Layout widgets are used to position other widgets on the screen. For example, the HORIZONTAL layout widget places the widgets it encapsulates horizontally on the screen.

### VERTICAL
The VERTICAL widget places the widgets it encapsulates vertically on the screen. The screen defaults to a vertical layout, so if no layout widgets are specified, all widgets will be automatically placed within a VERTICAL layout widget. The VERTICAL widget sizes itself to fit its contents.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Vertical Spacing | Vertical spacing between widgets in pixels (default = 3) | No |
| Vertical Packing | Pack all widgets vertically (default = true) | No |

Example Usage:
{% highlight bash %}
VERTICAL 50
  LABEL "TEST"
  LABEL "SCREEN"
END
{% endhighlight %}

### VERTICALBOX
The VERTICALBOX widget places the widgets it encapsulates vertically on the screen inside of a thin border. The VERTICALBOX widget sizes itself to fit its contents vertically and to fit the screen horizontally.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Title | Text to place within the border to label the box | No |
| Vertical Spacing | Vertical spacing between widgets in pixels (default = 3) | No |
| Vertical Packing | Pack all widgets vertically (default = true) | No |

Example Usage:
{% highlight bash %}
VERTICALBOX Info
  LABEL "TEST"
  LABEL "SCREEN"
END
{% endhighlight %}

### HORIZONTAL
The HORIZONTAL widget places the widgets it encapsulates horizontally on the screen. The HORIZONTAL widget sizes itself to fit its contents.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Horizontal Spacing | Horizontal spacing between widgets in pixels (default = 1) | No |

Example Usage:
{% highlight bash %}
HORIZONTAL 100
  LABEL "TEST"
  LABEL "SCREEN"
END
{% endhighlight %}

### HORIZONTALBOX
The HORIZONTALBOX widget places the widgets it encapsulates horizontally on the screen inside of a thin border. The HORIZONTALBOX widget sizes itself to fit its contents.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Title | Text to place within the border to label the box | No |
| Horizontal Spacing | Horizontal spacing between widgets in pixels (default = 0) | No |

Example Usage:
{% highlight bash %}
HORIZONTALBOX Info 10
  LABEL "TEST"
  LABEL "SCREEN"
END
{% endhighlight %}

### MATRIXBYCOLUMNS
The MATRIXBYCOLUMNS widget places the widgets into a table-like matrix. The MATRIXBYCOLUMNS widget sizes itself to fit its contents.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Columns | The number of columns to create | Yes |
| Horizontal Spacing | Spacing between horizontal items (default = 0) | No |
| Vertical Spacing | Spacing between vertical items (default = 0) | No |

Example Usage:
{% highlight bash %}
MATRIXBYCOLUMNS 3
  LABEL "COL 1"
  LABEL "COL 2"
  LABEL "COL 3"

  LABEL "100"
  LABEL "200"
  LABEL "300"
END
{% endhighlight %}

### SCROLLWINDOW
The SCROLLWINDOW widget places the widgets inside of it into a scrollable area. The SCROLLWINDOW widget sizes itself to fit the screen in which it is contained.

Example Usage:
{% highlight bash %}
SCROLLWINDOW
VERTICAL
 LABEL "100"
 LABEL "200"
 LABEL "300"
 LABEL "400"
 LABEL "500"
 LABEL "600"
 LABEL "700"
 LABEL "800"
 LABEL "900"
END
END
{% endhighlight %}

### TABBOOK
The TABBOOK widget creates a tabbed area in which to place TABITEM widgets to form a tabbed layout.

### TABITEM
The TABITEM widget creates a tab into which to place widgets. The tab automatically acts like a VERTICAL widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Tab Text | Text to diplay in the tab | Yes |

Example Usage:
{% highlight bash %}
TABBOOK
  TABITEM "Tab 1"
    LABEL "100"
    LABEL "200"
  END
  TABITEM "Tab 2"
    LABEL "300"
    LABEL "400"
  END
END
{% endhighlight %}

## Decoration Widgets
Decoration widgets are used to enhance the appearance of the screen. They do not respond to input, nor does the output vary with telemetry.

### LABEL
The LABEL widget displays text on the screen. Generally, label widgets contain a telemetry mnemonic and are placed next to the telemetry VALUE widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Text | Text to display on the label | Yes |

Example Usage:
{% highlight bash %}
LABEL "Note: This is only a warning"
{% endhighlight %}

### HORIZONTALLINE
The HORIZONTALLINE widget displays a horizontal line on the screen that can be used as a separator.

### SECTIONHEADER
The SECTIONHEADER widget displays a label that is underlined with a horizontal line. Generally, SECTIONHEADER widgets are the first widget placed inside of a VERTICALBOX widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Text | Text to display above the horizontal line | Yes |

Example Usage:
{% highlight bash %}
SECTIONHEADER Mechanisms
{% endhighlight %}

### TITLE
The TITLE widget displays a large centered title on the screen.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Text | Text to display above the horizontal line | Yes |

Example Usage:
{% highlight bash %}
TITLE "Title"
HORIZONTALLINE
SECTIONHEADER "Section Header"
LABEL "Label"
{% endhighlight %}

### SPACER
The SPACER widget inserts a spacer into a layout. This can be used to separate or align other widgets. For more information about how the widget size policy works please see the [QSizePolicy::Policy](http://doc.qt.io/qt-4.8/qsizepolicy.html#Policy-enum).

| Parameter | Description | Required |
|-----------|-------------|----------|
| Width | The width of the spacer in pixels. | Yes |
| Height | The height of the spacer in pixels. | Yes |
| Horizontal Policy | The horizontal size policy of the spacer.  Can be FIXED, MINIMUM, MAXIMUM, PREFERRED, EXPANDING, MINIMUMEXPANDING, or IGNORED.  Defaults to MINIMUM. | No |
| Vertical Policy | The vertical size policy of the spacer.  Can be FIXED, MINIMUM, MAXIMUM, PREFERRED, EXPANDING, MINIMUMEXPANDING, or IGNORED.  Defaults to MINIMUM. | No |

Example Usage:
{% highlight bash %}
VERTICAL 3 FALSE
  LABEL "Spacer below"
  SPACER 0 100 MINIMUM EXPANDING
  LABEL "Spacer above"
END
{% endhighlight %}

### STRETCH
The STRETCH widget inserts stretch into a layout. Stretch expands to the end of the layout to help align other widgets in the layout.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Stretch Factor | Multiple stretch items can expand at different rates. By default stretch is added with value 1 but stretch is allocated according to the stretch factor.  | Yes |

Example Usage:
{% highlight bash %}
VERTICAL 3 FALSE
  LABEL "Stretch below"
  STRETCH
  LABEL "Stretch above"
END
{% endhighlight %}

## Telemetry widgets
Telemetry widgets are used to display telemetry values. The first parameters to each of these widgets is a telemetry mnemonic. Depending on the type and purpose of the telemetry item, the screen designer may select from a wide selection of widgets to display the value in the most useful format. They are listed here in alphabetical order.

### ARRAY
The ARRAY widget is used to display data from an array telemetry item. Data is organized into rows and by default space separated.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Width | Width of the widget (default = 200) | No |
| Height | Height of the widget (default = 100) | No |
| Format String | Format string applied to each array item (default = nil) | No |
| Items per Row | Number of array items per row (default = 4) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
ARRAY INST HEALTH_STATUS ARY 250 50 "0x%x" 6 FORMATTED
ARRAY INST HEALTH_STATUS ARY2 200 60 nil 4 WITH_UNITS
{% endhighlight %}

### BLOCK
The BLOCK widget is used to display data from a block telemetry item. Data is organized into rows and space separated.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Width | Width of the widget (default = 200) | No |
| Height | Height of the widget (default = 100) | No |
| Format String | Format string applied to byte of the block (default = "%02X") | No |
| Bytes per Word | Number of bytes per word (default = 4) | No |
| Words per Row | Number of words per row (default = 4) | No |
| Address Format | Format for the address printed at the beginning of each line (default = nil which means do not print an address) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = RAW) | No |

Example Usage:
{% highlight bash %}
BLOCK INST IMAGE IMAGE 400 130 "%02X" 4 4 "0x%08X:"
{% endhighlight %}

### FORMATFONTVALUE
The FORMATFONTVALUE widget displays a box with a value printed inside that is formatted by the specified string rather than by a format string given in the telemetry definition files. Additionally, this widget can use a specified font. The white portion of the box darkens to gray while the value remains stagnant, then brightens to white each time the value changes. Additionally the value is colored based on the items limits state (Red for example if it is out of limits).

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Format String | Printf style format string to apply to the telemetry item | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |
| Font Name | The font to use. (default = arial) | No |
| Font Size | The font size. (default = 100) | No |
| Font Weight | The font weight. See [QFont::Weight](http://doc.qt.io/qt-4.8/qfont.html#Weight-enum) for more information. (default = Qt::Font::Normal) | No |
| Font Italics | Whether to display the font in italics. (default = false) | No |

Example Usage:
{% highlight bash %}
FORMATFONTVALUE INST LATEST TIMESEC %012u CONVERTED 12 arial 15 Qt::Font::Bold true
{% endhighlight %}

### FORMATVALUE
The FORMATVALUE widget displays a box with a value printed inside that is formatted by the specified string rather than by a format string given in the telemetry definition files. The white portion of the box darkens to gray while the value remains stagnant, then brightens to white each time the value changes. Additionally the value is colored based on the items limits state (Red for example if it is out of limits).

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Format String | Printf style format string to apply to the telemetry item | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
FORMATVALUE INST LATEST TIMESEC %012u CONVERTED 12
{% endhighlight %}

### LABELFORMATVALUE
The LABELFORMATVALUE widget displays a label with a value box that is formatted by the specified string rather than by a format string given in the telemetry definition files. The white portion of the box darkens to gray while the value remains stagnant, then brightens to white each time the value changes. Additionally the value is colored based on the items limits state (Red for example if it is out of limits).

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Format String | Printf style format string to apply to the telemetry item | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
LABELFORMATVALUE INST LATEST TIMESEC %012u CONVERTED 12
{% endhighlight %}

### LABELPROGRESSBAR
The LABELPROGRESSBAR widget displays a LABEL widget showing the items name followed by a PROGRESSBAR widget to show the items value.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Scale Factor | Value to multiple the telemetry item by before displaying the in the progress bar. Final value should be in the range of 0 to 100. (default 1.0) | No |
| Width | Width of the progress bar (default = 80 pixels) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
LABELPROGRESSBAR INST ADCS POSPROGRESS 2 200 RAW
LABELPROGRESSBAR INST ADCS POSPROGRESS
{% endhighlight %}

### LABELTRENDLIMITSBAR
The LABELTRENDLIMITSBAR widget displays a LABEL widget to show the item's name, a VALUE widget to show the telemetry items current value, a VALUE widget to display the value of the item X seconds ago, and a TRENDBAR widget to display the items value within its limits ranges and its trend.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Trend Seconds | The number of seconds in the past to display the trend value (default = 60) | No |
| Characters | The number of characters to display the telemetry value (default = 12) | No |
| Width | Width of the limits bar (default = 160) | No |
| Height | Height of the limits bar (default = 25) | No |

Example Usage
{% highlight bash %}
LABELTRENDLIMITSBAR INST HEALTH_STATUS TEMP1 CONVERTED 5 20 200 50
LABELTRENDLIMITSBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### LABELVALUE
The LABELVALUE widget displays a LABEL widget to shows the telemetry items name followed by a VALUE widget to display the items value.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |
| Alignment | How to align the label and value items. Options are 'split', 'right', 'left', 'center'. (default = split) | No |

Example Usage:
{% highlight bash %}
LABELVALUE INST LATEST TIMESEC CONVERTED 18 center
LABELVALUE INST LATEST COLLECT_TYPE
{% endhighlight %}

### LABELVALUEDESC
The LABELVALUEDESC widget displays a LABEL widget to shows the telemetry items description followed by a VALUE widget to display the items value.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Description | The description to display in the label (default is to display the description text associated with the telemetry item) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
LABELVALUEDESC INST LATEST TIMESEC "Time in seconds" CONVERTED 18
LABELVALUEDESC INST LATEST COLLECT_TYPE
{% endhighlight %}

### LABELVALUELIMITSBAR
The LABELVALUELIMITSBAR widget displays a LABEL widget to shows the telemetry item's name, followed by a VALUE widget to display the items value, followed by a LIMITSBAR widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP1 CONVERTED 18
LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### LABELVALUELIMITSCOLUMN
The LABELVALUELIMITSCOLUMN widget displays a LABEL widget to shows the telemetry item's name, followed by a VALUE widget to display the items value, followed by a LIMITSCOLUMN widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
LABELVALUELIMITSCOLUMN INST HEALTH_STATUS TEMP1 CONVERTED 18
LABELVALUELIMITSCOLUMN INST HEALTH_STATUS TEMP1
{% endhighlight %}

### LABELVALUERANGEBAR
The LABELVALUERANGEBAR widget displays a LABEL widget to shows the telemetry item's name, followed by a VALUE widget to display the items value, followed by a RANGEBAR widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |
| Width | Width of the range bar (default = 160) | No |
| Height | Height of the range bar (default = 25) | No |

Example Usage:
{% highlight bash %}
LABELVALUERANGEBAR INST HEALTH_STATUS TEMP1 0 50 CONVERTED 18 200 50
LABELVALUERANGEBAR INST HEALTH_STATUS TEMP1 0 50
{% endhighlight %}

### LABELVALUERANGECOLUMN
The LABELVALUERANGECOLUMN widget displays a LABEL widget to shows the telemetry item's name, followed by a VALUE widget to display the items value, followed by a RANGECOLUMN widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 8) | No |
| Width | Width of the range bar (default = 30) | No |
| Height | Height of the range bar (default = 100) | No |

Example Usage:
{% highlight bash %}
LABELVALUERANGECOLUMN INST HEALTH_STATUS TEMP1 0 50 CONVERTED 18 50 200
LABELVALUERANGECOLUMN INST HEALTH_STATUS TEMP1 0 50
{% endhighlight %}

### LIMITSBAR
The LIMITSBAR widget displays a graphical representation of where an items value falls withing its limits ranges horizontally.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Width | The width of the range bar (default = 160) | No |
| Height | The height of the range bar (default = 25) | No |

Example Usage:
{% highlight bash %}
LIMITSBAR INST HEALTH_STATUS TEMP1 CONVERTED 200 50
LIMITSBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### LIMITSCOLUMN
The LIMITSCOLUMN widget displays a graphical representation of where an items value falls withing its limits ranges vertically.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Width | The width of the range bar (default = 30) | No |
| Height | The height of the range bar (default = 100) | No |

Example Usage:
{% highlight bash %}
LIMITSCOLUMN INST HEALTH_STATUS TEMP1 CONVERTED 50 200
LIMITSCOLUMN INST HEALTH_STATUS TEMP1
{% endhighlight %}

### LIMITSCOLOR
The LIMITSCOLOR widget displays a stoplight-like circle depicting the limits color of an item

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Radius | Radius of the circle (default = 10 pixels) | No |
| Full Item Name | Show the full item name (default = false) | No |

Example Usage:
{% highlight bash %}
LIMITSCOLOR INST HEALTH_STATUS TEMP1 CONVERTED 20 TRUE
LIMITSCOLOR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### VALUELIMITSBAR
The VALUELIMITSBAR widget displays a graphical representation of where an items value falls withing its limits ranges horizontally and its value in a VALUE widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |

Example Usage:
{% highlight bash %}
VALUELIMITSBAR INST HEALTH_STATUS TEMP1 CONVERTED 18
VALUELIMITSBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### VALUELIMITSCOLUMN
The VALUELIMITSCOLUMN widget displays a graphical representation of where an items value falls withing its limits ranges vertically and its value in a VALUE widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 8) | No |

Example Usage:
{% highlight bash %}
VALUELIMITSCOLUMN INST HEALTH_STATUS TEMP1 CONVERTED 18
VALUELIMITSCOLUMN INST HEALTH_STATUS TEMP1
{% endhighlight %}

### VALUERANGEBAR
The VALUERANGEBAR widget displays a graphical representation of where an items value falls withing a range horizontally and its value in a VALUE widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 12) | No |
| Width | Width of the range bar (default = 160) | No |
| Height | Height of the range bar (default = 25) | No |

Example Usage:
{% highlight bash %}
VALUERANGEBAR INST HEALTH_STATUS TEMP1 0 100 CONVERTED 18 200 50
VALUERANGEBAR INST HEALTH_STATUS TEMP1 -1000 1000
{% endhighlight %}

### VALUERANGECOLUMN
The VALUERANGECOLUMN widget displays a graphical representation of where an items value falls withing a range vertically and its value in a VALUE widget..

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Number of Characters | The number of characters wide to make the value box (default = 8) | No |
| Width | Width of the range bar (default = 30) | No |
| Height | Height of the range bar (default = 100) | No |

Example Usage:
{% highlight bash %}
VALUERANGECOLUMN INST HEALTH_STATUS TEMP1 0 100 CONVERTED 18 50 200
VALUERANGECOLUMN INST HEALTH_STATUS TEMP1 -1000 1000
{% endhighlight %}

### LINEGRAPH
The LINEGRAPH widget displays a line graph of a telemetry items value verses sample number.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Num Samples | The number of samples to display on the graph (default = 100) | No |
| Width | The width of the graph (default = 300) | No |
| Height | The height of the graph (default = 200) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
LINEGRAPH INST HEALTH_STATUS TEMP1
LINEGRAPH INST HEALTH_STATUS TEMP1 10 400 100 RAW
{% endhighlight %}

### PROGRESSBAR
The PROGRESSBAR widget displays a progress bar that is useful for displaying percentages.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Scale Factor | Value to multiple the telemetry item by before displaying the in the progress bar. Final value should be in the range of 0 to 100. (default 1.0) | No |
| Width | Width of the progress bar (default = 80 pixels) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
PROGRESSBAR INST ADCS POSPROGRESS 0.5 200
PROGRESSBAR INST ADCS POSPROGRESS
{% endhighlight %}

### RANGEBAR
The RANGEBAR widget displays a graphical representation of where an items value falls withing a range horizontally.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Width | Width of the range bar (default = 160) | No |
| Height | Height of the range bar (default = 25) | No |

Example Usage:
{% highlight bash %}
RANGEBAR INST HEALTH_STATUS TEMP1 0 100 CONVERTED 200 50
RANGEBAR INST HEALTH_STATUS TEMP1 -1000 1000
{% endhighlight %}

### RANGECOLUMN
The RANGECOLUMN widget displays a graphical representation of where an items value falls withing a range vertically.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Low Value | Minimum value to display on the range bar. If the telemetry item goes below this value the bar is "pegged" on the low end. | Yes |
| High Value | Maximum value to display on the range bar. If the telemetry item goes above this value the bar is "pegged" on the high end. | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Width | Width of the range bar (default = 30) | No |
| Height | Height of the range bar (default = 100) | No |

Example Usage:
{% highlight bash %}
RANGECOLUMN INST HEALTH_STATUS TEMP1 0 100 CONVERTED 50 200
RANGECOLUMN INST HEALTH_STATUS TEMP1 -1000 1000
{% endhighlight %}

### TEXTBOX
The TEXTBOX widget provides a large box for multiline text.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Width | Width of the text box (default = 200) | No |
| Height | Height of the text box (default = 100) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
TEXTBOX INST HEALTH_STATUS TIMEFORMATTED 150 50
TEXTBOX INST HEALTH_STATUS TIMEFORMATTED
{% endhighlight %}

### TIMEGRAPH
The TIMEGRAPH widget displays a line graph of a telemetry items value verses time.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Num Samples | The number of samples to display on the graph (default = 100) | No |
| Width | The width of the graph (default = 300) | No |
| Height | The height of the graph (default = 200) | No |
| Point Size | Size of the point in pixels (default = 5) | No |
| Time Item Name | The telemetry item to use as the time on the X axis (default = PACKET_TIMESECONDS) | No |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
TIMEGRAPH INST HEALTH_STATUS TEMP1
TIMEGRAPH INST HEALTH_STATUS TEMP1 10 400 100 false TIMESECONDS CONVERTED
{% endhighlight %}

### TRENDBAR
The TRENDBAR widget provides the same functionality as the LIMITSBAR widget except that it also keeps a history of the telemetry item and graphically shows where the value was X seconds ago.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Value Type | The type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |
| Trend Seconds | The number of seconds in the past to display the trend value (default = 60) | No |
| Width | Width of the limits bar (default = 160) | No |
| Height | Height of the limits bar (default = 25) | No |

Example Usage
{% highlight bash %}
TRENDBAR INST HEALTH_STATUS TEMP1 CONVERTED 20 200 50
TRENDBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### TRENDLIMITSBAR
The TRENDLIMITSBAR widget displays a VALUE widget to show the telemetry items current value, a VALUE widget to display the value of the item X seconds ago, and a TRENDBAR widget to display the items value within its limits ranges and its trend.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Target name portion of the telemetry mnemonic | Yes |
| Packet Name | Packet name portion of the telemetry mnemonic | Yes |
| Item Name | Item name portion of the telemetry mnemonic | Yes |
| Value Type | Type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Trend Seconds | Number of seconds in the past to display the trend value (default = 60) | No |
| Characters | Number of characters to display the value (default = 12) | No |
| Width | Width of the limits bar (default = 160) | No |
| Height | Height of the limits bar (default = 25) | No |

Example Usage
{% highlight bash %}
TRENDLIMITSBAR INST HEALTH_STATUS TEMP1 CONVERTED 20 20 200 50
TRENDLIMITSBAR INST HEALTH_STATUS TEMP1
{% endhighlight %}

### VALUE
The VALUE widget displays a box with a value printed inside. The white portion of the box darkens to gray while the value remains stagnant, then brightens to white each time the value changes. Additionally the value is colored based on the items limits state (Red for example if it is out of limits).

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Target name portion of the telemetry mnemonic | Yes |
| Packet Name | Packet name portion of the telemetry mnemonic | Yes |
| Item Name | Item name portion of the telemetry mnemonic | Yes |
| Value Type | Type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = WITH_UNITS) | No |
| Characters | Number of characters to display the value (default = 12) | No |

Example Usage:
{% highlight bash %}
VALUE INST HEALTH_STATUS TEMP1 CONVERTED 18
VALUE INST HEALTH_STATUS TEMP1
{% endhighlight %}

## Interactive Widgets
Interactive widgets are used to gather input from the user. Unlike all other widgets, which only output some graphical representation, interactive widgets permit input either from the keyboard or mouse.

### BUTTON
The BUTTON widget displays a rectangular button that is clickable by the mouse. Upon clicking, the button executes the Ruby code assigned. Buttons can be used to send commands and perform other tasks.

If you want your button to use values from other widgets, define them as named widgets and read their values using the `get_named_widget("WIDGET_NAME").text` method. See the example in CHECKBUTTON. If your button logic gets complex it's recommended to `require` a separate script and pass the screen to the script using self such as `require utility.rb; utility_method(self)`.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Button Text | Text displayed on the button | Yes |
| String to Eval | Ruby code to execute when the button is pressed | Yes |

Example Usage to execute a command:
{% highlight bash %}
BUTTON 'Start Collect' 'cmd("INST COLLECT with TYPE NORMAL, DURATION 5")'
{% endhighlight %}
Example Usage to open Script Runner with a given script:
{% highlight bash %}
BUTTON "Run Script" 'system("ruby #{Cosmos::USERPATH}/tools/ScriptRunner #{Cosmos::USERPATH}/procedures/checks.rb")'
{% endhighlight %}

### CHECKBUTTON
The CHECKBUTTON widget displays a check box. Note this is of limited use by itself and is primarily used in conjunction with NAMED_WIDGET.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Checkbox Text | Text displayed next to the checkbox | Yes |
| Checked | Whether the checkbox should initially be checked. Valid values are 'CHECKED' or 'UNCHECKED'. (default = 'UNCHECKED') | No |

Example Usage:
{% highlight bash %}
NAMED_WIDGET CHECK CHECKBUTTON 'Ignore Hazardous Checks'
BUTTON 'Send' 'if get_named_widget("CHECK").checked? then cmd_no_hazardous_check("INST CLEAR") else cmd("INST CLEAR") end'
{% endhighlight %}

### COMBOBOX
The COMBOBOX widget displays a drop down list of text items that the user can choose from. Note this is of limited use by itself and is primarily used in conjunction with NAMED_WIDGET.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Option Text 1 | Text to display in the selection drop down | Yes |
| Option Text n | Text to display in the selection drop down | No |

Example Usage:
{% highlight bash %}
BUTTON 'Start Collect' 'cmd("INST COLLECT with TYPE #{get_named_widget("COLLECT_TYPE").text}, DURATION 10.0")'
NAMED_WIDGET COLLECT_TYPE COMBOBOX NORMAL SPECIAL
{% endhighlight %}

### RADIOBUTTON
The RADIOBUTTON widget a radio button and text. Note this is of limited use by itself and is primarily used in conjunction with NAMED_WIDGET.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Text | Text to display next to the radio button | Yes |
| Checked | Whether the radio button should initially be checked. Valid values are 'CHECKED' or 'UNCHECKED'. (default = 'UNCHECKED') | No |

Example Usage:
{% highlight bash %}
NAMED_WIDGET ABORT RADIOBUTTON 'Abort'
NAMED_WIDGET CLEAR RADIOBUTTON 'Clear'
BUTTON 'Send' 'if get_named_widget("ABORT").checked? then cmd("INST ABORT") else cmd("INST CLEAR") end'
{% endhighlight %}

### TEXTFIELD
The TEXTFIELD widget displays a rectangular box that the user can enter text into.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Characters | Width of the text field in characters (default = 12) | No |
| Text | Default text to put in the text field (default is blank) | No |

Example Usage:
{% highlight bash %}
NAMED_WIDGET DURATION TEXTFIELD 12 "10.0"
BUTTON 'Start Collect' 'cmd("INST COLLECT with TYPE NORMAL, DURATION #{get_named_widget("DURATION").text.to_f}")'
{% endhighlight %}

### SCREENSHOTBUTTON
The SCREENSHOTBUTTON widget displays a button that when clicked takes a screenshot.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Button Text | Text to display on the button. (default = "Screenshot") | No |
| Directory | Directory to save the screenshot. (default = System.paths['LOGS']) | No |

Example Usage:
{% highlight bash %}
SCREENSHOTBUTTON "Screenshot" "C:/images/screenshots"
{% endhighlight %}

## Canvas Widgets
Canvas Widgets are used to draw custom displays into telemetry screens. The canvas coordinate frame places (0,0) in the upper-left corner of the canvas.

### CANVAS
The CANVAS widget is the layout widget for the other canvas widgets. All canvas widgets must be enclosed within a CANVAS widget. It is included with the other CANVAS widgets rather than in the layout section for simplicity.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Width | Width of the canvas | Yes |
| Height | Height of the canvas | Yes |

Example Usage: See the other Canvas examples

### CANVASLABEL
The CANVASLABEL widget draws text onto the canvas.

| Parameter | Description | Required |
|-----------|-------------|----------|
| X | X position of the upper-left corner of the text on the canvas | Yes |
| Y | Y position of the upper-left corner of the text on the canvas | Yes |
| Text | Text to draw onto the canvas | Yes |
| Font Size | Font size of the text (default = 12) | No |
| Color | Color of the text (default = 'black') | No |

Example Usage:
{% highlight bash %}
CANVAS 100 100
  CANVASLABEL 5 34 "Label1" 24 red
  CANVASLABEL 5 70 "Label2" 18 blue
END
{% endhighlight %}

### CANVASLABELVALUE
The CANVASLABELVALUE widget draws the text value of a telemetry item onto the canvas in an optional frame.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| X | X position of the upper-left corner of the text on the canvas | Yes |
| Y | Y position of the upper-left corner of the text on the canvas | Yes |
| Font Size | Font size of the text (default = 12) | No |
| Color | Color of the text (default = 'black')	| No |
| Frame | Whether to draw a frame around the value in the same color as the font (default = true) | No |
| Frame Width | Width in pixels of the frame (default = 3) | No |
| Value Type | Type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = CONVERTED) | No |

Example Usage:
{% highlight bash %}
CANVAS 200 100
  CANVASLABELVALUE INST HEALTH_STATUS TEMP1 5 34 12 red true 5
  CANVASLABELVALUE INST HEALTH_STATUS TEMP2 5 70 10 blue false 0 WITH_UNITS
END
{% endhighlight %}

### CANVASIMAGE
The CANVASIMAGE widget displays a GIF image on the canvas.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Image Name | Name of a image file. The file must be located in the <Cosmos::USERPATH>/data directory. | Yes |
| X | Left X position to draw the image | Yes |
| Y | Top Y position to draw the image | Yes |

Example Usage:
{% highlight bash %}
CANVAS 300 300
  CANVASIMAGE "satellite.gif" 0 0
END
{% endhighlight %}

### CANVASIMAGEVALUE
The CANVASIMAGEVALUE widget displays a GIF image on the canvas that changes with a telemetry value.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Target name portion of the telemetry mnemonic | Yes |
| Packet Name | Packet name portion of the telemetry mnemonic | Yes |
| Item Name | Item name portion of the telemetry mnemonic | Yes |
| Filename Prefix | The prefix part of the filename of the gif images (expected to be in the user's data directory). The actual filenames will be this value plus the word "on" or the word "off" and ".gif" | Yes |
| X | X position of the upper-left corner of the image on the canvas | Yes |
| Y | Y position of the upper-left corner of the image on the canvas | Yes |
| Value Type | Type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = RAW) | No |

Example Usage:
{% highlight bash %}
CANVAS 150 200
  CANVASLABELVALUE INST HEALTH_STATUS GROUND1STATUS 0 12 12 black false
  CANVASIMAGEVALUE INST HEALTH_STATUS GROUND1STATUS "ground" 0 20 # Uses groundon.gif and groundoff.gif
END
{% endhighlight %}

### CANVASLINE
The CANVASLINE widget draws a line onto the canvas.

| Parameter | Description | Required |
|-----------|-------------|----------|
| X1 | X position of the first endpoint of the line on the canvas | Yes |
| Y1 | Y position of the first endpoint of the line on the canvas | Yes |
| X2 | X position of the second endpoint of the line on the canvas | Yes |
| Y2 | Y position of the second endpoint of the line on the canvas | Yes |
| Color | Color of the line(default = 'black') | No |
| Width | Width of the line in pixels (default = 1) | No |
| Connector | Indicates whether or not to draw a circle at the second endpoint of the line: NO_CONNECTOR or CONNECTOR (default = NO_CONNECTOR) | No |

Example Usage:
{% highlight bash %}
CANVAS 100 50
  CANVASLINE 5 5 95 5
  CANVASLINE 5 5 5 45 green 2 CONNECTOR
  CANVASLINE 95 5 95 45 blue 3 CONNECTOR
END
{% endhighlight %}

### CANVASLINEVALUE
The CANVASLINEVALUE widget draws a line onto the canvas in one of two colors based on the value of the associated telemetry item.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | Target name portion of the telemetry mnemonic | Yes |
| Packet Name | Packet name portion of the telemetry mnemonic | Yes |
| Item Name | Item name portion of the telemetry mnemonic | Yes |
| X1 | X position of the first endpoint of the line on the canvas | Yes |
| Y1 | Y position of the first endpoint of the line on the canvas | Yes |
| X2 | X position of the second endpoint of the line on the canvas | Yes |
| Y2 | Y position of the second endpoint of the line on the canvas | Yes |
| Color On | Color of the line when the telemtry point is considered on (default = 'green') | No |
| Color Off | Color of the line when the telemtry point is considered off (default = 'blue') | No |
| Width | Width of the line in pixels (default = 3) | No |
| Connector | Indicates whether or not to draw a circle at the second endpoint of the line: NO_CONNECTOR or CONNECTOR (default = NO_CONNECTOR) | No |
| Value Type | Type of the value to display: RAW, CONVERTED, FORMATTED, or WITH_UNITS (default = RAW) | No |

Example Usage:
{% highlight bash %}
CANVAS 120 50
  CANVASLABELVALUE INST HEALTH_STATUS GROUND1STATUS 0 12 12 black false
  CANVASLINEVALUE INST HEALTH_STATUS GROUND1STATUS 5 25 115 25
  CANVASLINEVALUE INST HEALTH_STATUS GROUND1STATUS 5 45 115 45 purple red 3 CONNECTOR
END
{% endhighlight %}

### CANVASDOT
The CANVASDOT widget draws a dot onto the canvas, and it can be programmed to change its position with ruby code.

| Parameter | Description | Required |
|-----------|-------------|----------|
| X __or__ Str to Eval | X position of the dot, or it can be a string of ruby code | Yes |
| Y __or__ Str to Eval | Y position of the dot, or it can be a string of ruby code | Yes |
| Color | Color of the dot (default = black) | No |
| Width | Width of the dot in pixels (default = 3) | No |

Example Usage:
{% highlight bash %}
CANVAS 201 201
  CANVASLINE 0 0 200 0
  CANVASLINE 200 0 200 200
  CANVASLINE 200 200 0 200
  CANVASLINE 0 200 0 0
  CANVASLINE 99 1 99 199 white
  CANVASLINE 1 99 199 99 white
  CANVASDOT 'tlm_variable("GIMBAL AXIS_STATUS_X POSITION", :RAW) + 100' 'tlm_variable("GIMBAL AXIS_STATUS_Y POSITION", :RAW) + 100' red
END
{% endhighlight %}

![720311333_78794](https://cloud.githubusercontent.com/assets/5217851/11122513/d29af8c0-8918-11e5-9138-17011956911a.jpg)

## Widget Settings
Settings allow for additional tweaks and options to be applied to widgets that are not available in their constructors. These settings are all configured through the SETTING and GLOBAL_SETTING keywords. SETTING applies only to the widget defined immediately before it. GLOBAL_SETTING applies to all widgets.

## Common Settings
The following settings are available to all widgets if their underlying Qt GUI object supports them.

### BACKCOLOR
The BACKCOLOR setting sets the background color for a widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Color Name | Common name for the color, e.g. 'black', 'red', etc | Yes |

or

| Parameter | Description | Required |
|-----------|-------------|----------|
| Red Value | Red portion of an RGB value (0-255) | Yes |
| Green Value | Green portion of an RGB value (0-255) | Yes |
| Blue Value | Blue portion of an RGB value (0-255) | Yes |

Example Usage:
{% highlight bash %}
SETTING BACKCOLOR red
SETTING BACKCOLOR 162 181 205
{% endhighlight %}

### TEXTCOLOR
The TEXTCOLOR setting sets the text color for a widget.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Color Name | Common name for the color, e.g. 'black', 'red', etc | Yes |

| Parameter | Description | Required |
|-----------|-------------|----------|
| Red Value | Red portion of an RGB value (0-255) | Yes |
| Green Value | Green portion of an RGB value (0-255) | Yes |
| Blue Value | Blue portion of an RGB value (0-255) | Yes |

Example Usage:
{% highlight bash %}
SETTING TEXTCOLOR red
SETTING TEXTCOLOR 162 181 205
{% endhighlight %}

### WIDTH
The WIDTH setting forces the height of a widget to a certain size.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Width | Desired with in pixels | Yes |

Example Usage:
{% highlight bash %}
SETTING WIDTH 100
{% endhighlight %}

### HEIGHT
The HEIGHT setting forces the height of a widget to a certain size.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Height | Desired height in pixels | Yes |

Example Usage:
{% highlight bash %}
SETTING HEIGHT 100
{% endhighlight %}

## Widget-Specific Settings
The following settings are only available to the widgets listed.

### BORDERCOLOR
The BORDERCOLOR setting changes the color of a layout widgets border.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Color Name | Common name for the color, e.g. 'black', 'red', etc | Yes |

or

| Parameter | Description | Required |
|-----------|-------------|----------|
| Red Value | Red portion of an RGB value (0-255) | Yes |
| Green Value | Green portion of an RGB value (0-255) | Yes |
| Blue Value | Blue portion of an RGB value (0-255) | Yes |

Example Usage:
{% highlight bash %}
HORIZONTALBOX
  LABEL "Label 1"
  LABEL "Label 2"
END
SETTING BORDERCOLOR red
{% endhighlight %}

### COLORBLIND
The COLORBLIND setting enables/disables providing clues in visualization for users that are colorblind. Supported by all VALUE widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Enable | TRUE or FALSE | Yes |

Example Usage:
{% highlight bash %}
LABELVALUELIMITSBAR INST HEALTH_STATUS TEMP1
  SETTING COLORBLIND TRUE
{% endhighlight %}

### ENABLE_AGING
The ENABLE_AGING setting enables/disables graying of widgets if there value doesn't change. Supported by ARRAY, BLOCK, and all VALUE widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Enable | TRUE or FALSE | Yes |

Example Usage:
{% highlight bash %}
LABELVALUE INST HEALTH_STATUS COLLECTS
  SETTING ENABLE_AGING FALSE
{% endhighlight %}

### GRAY_RATE / GREY_RATE
The GRAY_RATE and GREY_RATE settings change the rate at which graying occurs in widgets. Supported by ARRAY, BLOCK, and all VALUE widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Gray Rate | The number of shades of gray that are subtracted at each polling period if the value hasn't changed	| Yes |

Example Usage:
{% highlight bash %}
LABELVALUE INST HEALTH_STATUS COLLECTS
  SETTING GRAY_RATE 5
{% endhighlight %}

### GRAY_TOLERANCE / GREY_TOLERANCE
The GRAY_TOLERANCE and GREY_TOLERANCE settings set the maximum change in value that will not cause the widget to recognize an items value as changing. Supported by all VALUE widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Tolerance Value | The maximum change in value that will cause the widget to not recognize an items value as changing. | Yes |

Example Usage:
{% highlight bash %}
LABELVALUE INST HEALTH_STATUS COLLECTS
  SETTING GRAY_TOLERANCE 1
{% endhighlight %}

### MIN_GRAY / MIN_GREY
The MIN_GRAY and MIN_GREY settings set the minimum shade of a gray that a widget will decay to if its value doesn't change. Supported by ARRAY, BLOCK, and all VALUE widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Minimum Gray | The minimum shade of a gray that a widget will decay to if its value doesn't change. Must be a value between 0 (black) and 255 (white). (default = 200) | Yes |

Example Usage:
{% highlight bash %}
LABELVALUE INST HEALTH_STATUS TEMP1
  SETTING GRAY_TOLERANCE 1000 # Prevent the widget from refreshing by choosing a high tolerance
  SETTING MIN_GRAY 0 # Set the minimum gray to black
{% endhighlight %}

### TREND_SECONDS
The TREND_SECONDS setting changes the number of seconds using during trending. Supported by the TREND widgets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Seconds | The number of seconds to trend across | Yes |

Example Usage:
{% highlight bash %}
TRENDBAR INST HEALTH_STATUS TEMP1
  SETTING TREND_SECONDS 10
{% endhighlight %}

### VALUE_EQ
The VALUE_EQ setting configures for an equal to comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Value | The value to compare against with == | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS GROUND1STATUS "ground" 400 100
  SETTING VALUE_EQ 0
{% endhighlight %}

### VALUE_GT
The VALUE_GT setting configures for a greater than comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Value | The value to compare against with > | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
  SETTING VALUE_GT 10.0
{% endhighlight %}

### VALUE_GTEQ
The VALUE_GTEQ setting configures for a greater than or equal to comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Value | The value to compare against with >= | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
  SETTING VALUE_GTEQ 10.0
{% endhighlight %}

### VALUE_LT
The VALUE_LT setting configures for a less than comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Value | The value to compare against with < | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
  SETTING VALUE_LT 10.0
{% endhighlight %}

### VALUE_LTEQ
The VALUE_LTEQ setting configures for a less than or equal to comparison for a canvas value widget to determine 'ON' state.
Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Value | The value to compare against with <= | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
SETTING VALUE_LTEQ 10.0
{% endhighlight %}

### TLM_AND
The TLM_AND setting allows added another comparison that is anded with the original comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Comparison Type | The comparison type: VALUE_EQ, VALUE_GT, VALUE_GTEQ, VALUE_LT, or VALUE_LTEQ | Yes |
| Value | The value to compare against | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
  SETTING VALUE_LTEQ 10.0
  SETTING TLM_AND INST HEALTH_STATUS TEMP2 VALUE_GT 20.0
{% endhighlight %}

### TLM_OR
The TLM_OR setting allows added another comparison that is ored with the original comparison for a canvas value widget to determine 'ON' state.  Supported widgets: CANVASIMAGEVALUE, CANVASLABELVALUE, CANVASLINEVALUE.

| Parameter | Description | Required |
|-----------|-------------|----------|
| Target Name | The target name portion of the telemetry mnemonic | Yes |
| Packet Name | The packet name portion of the telemetry mnemonic | Yes |
| Item Name | The item name portion of the telemetry mnemonic | Yes |
| Comparison Type | The comparison type: VALUE_EQ, VALUE_GT, VALUE_GTEQ, VALUE_LT, or VALUE_LTEQ | Yes |
| Value | The value to compare against | Yes |

Example Usage:
{% highlight bash %}
CANVASIMAGEVALUE INST HEALTH_STATUS TEMP1 "ground" 400 100
  SETTING VALUE_LTEQ 10.0
  SETTING TLM_OR INST HEALTH_STATUS TEMP2 VALUE_GT 20.0
{% endhighlight %}
