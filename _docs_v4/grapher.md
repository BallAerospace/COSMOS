---
layout: docs_v4
title: Telemetry Grapher
toc: true
---

This document describes Telemetry Grapher configuration file parameters.

<div style="clear:both;"></div>

## Telemetry Grapher Configuration Files

Telemetry Grapher configurations can be saved in configuration files. It is usually easiest to configure Telemetry Grapher and then save the configuration using the save option in the File menu. However, telemetry grapher configuration files can be created manually. Telemetry Grapher configuration files include some global keywords, and then a series of hierarchical keywords to describe tabs, plots, and data objects. By default, Telemetry Grapher will use the tlm_grapher.txt file in config/tools/tlm_grapher, but other configuration files can be loaded from the File menu or specified when starting Telemetry Grapher on the command line with the -c option.

## Global Keywords

### POINTS_SAVED

The POINTS_SAVED keyword defines the number of data points that Telemetry Grapher will store before it begins to discard old points in favor of new ones.

| Parameter    | Description                                                     | Required |
| ------------ | --------------------------------------------------------------- | -------- |
| Points Saved | Number of points saved by Telemetry Grapher (default = 1000000) | Yes      |

Example Usage:
{% highlight bash %}
POINTS_SAVED 1000000
{% endhighlight %}

### SECONDS_PLOTTED

The SECONDS_PLOTTED keyword defines the number of seconds of telemetry that will be plotted on the main Telemetry Grapher display.

| Parameter       | Description                                                                | Required |
| --------------- | -------------------------------------------------------------------------- | -------- |
| Seconds Plotted | Number of seconds of data displayed by Telemetry Grapher (default = 100.0) | Yes      |

Example Usage:
{% highlight bash %}
SECONDS_PLOTTED 100.0
{% endhighlight %}

### POINTS_PLOTTED

The POINTS_PLOTTED keyword defines the number of points that will be plotted on the main Telemetry Grapher display.

| Parameter      | Description                                                           | Required |
| -------------- | --------------------------------------------------------------------- | -------- |
| Points Plotted | Number of data points displayed by Telemetry Grapher (default = 1000) | Yes      |

Example Usage:
{% highlight bash %}
POINTS_PLOTTED 1000
{% endhighlight %}

### REFRESH_RATE_HZ

The REFRESH_RATE_HZ keyword defines the rate at which Telemetry Grapher will query new information from CTS and fresh the display.

| Parameter       | Description                                              | Required |
| --------------- | -------------------------------------------------------- | -------- |
| Refresh Rate Hz | Telemetry Grapher refresh rate in Hertz (default = 10.0) | Yes      |

Example Usage:
{% highlight bash %}
REFRESH_RATE_HZ 10.0
{% endhighlight %}

### CTS_TIMEOUT (COSMOS >= 3.9.2)

The CTS_TIMEOUT keyword defines the read timeout for the interface between Telemetry Grapher and the CTS. If Telemetry Grapher is being used to graph low-rate telemetry, it may be necessary to increse this timeout.

| Parameter   | Description                                  | Required |
| ----------- | -------------------------------------------- | -------- |
| CTS Timeout | CTS read timeout in seconds (default = 10.0) | Yes      |

Example Usage:
{% highlight bash %}
CTS_TIMEOUT 10.0
{% endhighlight %}

## Tab Keywords

### TAB

The TAB keyword is used to define a new tab in Telemetry Grapher. A tab must be defined before a plot can be added.

| Parameter | Description                                                 | Required |
| --------- | ----------------------------------------------------------- | -------- |
| Tab Name  | Title for the tab that will be created in Telemetry Grapher | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
{% endhighlight %}

## Plot Keywords

### PLOT

The PLOT keyword is used to define a new plot in Telemetry Grapher. A plot must be defined before a data object can be added. The plot will be added to the most recently defined tab in the configuration file.

| Parameter | Description                                                     | Required |
| --------- | --------------------------------------------------------------- | -------- |
| Plot type | Type of plot that will be created (LINEGRAPH, SINGLEXY, or XY). | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
{% endhighlight %}

### TITLE

The TITLE keyword is used to set the title for a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter  | Description | Required |
| ---------- | ----------- | -------- |
| Title text | Plot title  | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
TITLE "Plot Title"
{% endhighlight %}

### X_AXIS_TITLE

The X_AXIS_TITLE keyword is used to set the title for a plot's x-axis. This keyword applies to the most recently defined plot in the configuration file.

| Parameter         | Description  | Required |
| ----------------- | ------------ | -------- |
| X-axis title text | X-axis title | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
X_AXIS_TITLE "X-axis Title"
{% endhighlight %}

### Y_AXIS_TITLE

The Y_AXIS_TITLE keyword is used to set the title for a plot's y-axis. This keyword applies to the most recently defined plot in the configuration file.

| Parameter         | Description  | Required |
| ----------------- | ------------ | -------- |
| Y-axis title text | Y-axis title | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
Y_AXIS_TITLE "Y-axis Title"
{% endhighlight %}

### SHOW_X_GRID_LINES

The SHOW_X_GRID_LINES keyword is used to enable or disable display of the X grid lines for a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter    | Description                       | Required |
| ------------ | --------------------------------- | -------- |
| X Grid Lines | Show X grid lines (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
SHOW_X_GRID_LINES TRUE
{% endhighlight %}

### SHOW_Y_GRID_LINES

The SHOW_Y_GRID_LINES keyword is used to enable or disable display of the Y grid lines for a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter    | Description                       | Required |
| ------------ | --------------------------------- | -------- |
| Y Grid Lines | Show Y grid lines (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
SHOW_Y_GRID_LINES TRUE
{% endhighlight %}

### POINT_SIZE

The POINT_SIZE keyword is used to set the size of points shown on a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter  | Description          | Required |
| ---------- | -------------------- | -------- |
| Point Size | Point size in pixels | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
POINT_SIZE 7
{% endhighlight %}

### SHOW_LINES

The SHOW_LINES keyword is used to indicate whether or not points on a plot should be connected with lines. This keyword applies to the most recently defined plot in the configuration file.

| Parameter  | Description                               | Required |
| ---------- | ----------------------------------------- | -------- |
| Show lines | Connect points with lines (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
SHOW_LINES TRUE
{% endhighlight %}

### SHOW_LEGEND

The SHOW_LEGEND keyword is used to indicate whether or not to display the legend on a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter   | Description                      | Required |
| ----------- | -------------------------------- | -------- |
| Show legend | Show plot legend (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
SHOW_LEGEND TRUE
{% endhighlight %}

### MANUAL_Y_AXIS_SCALE

The MANUAL_Y_AXIS_SCALE keyword is used to set (and fix) the Y-axis scale on a plot. If the y-axis scale is not set, the plot will auto-scale based upon the contents. This keyword applies to the most recently defined plot in the configuration file.

| Parameter | Description                                         | Required |
| --------- | --------------------------------------------------- | -------- |
| Y min     | Minimum Y value                                     | Yes      |
| Y max     | Maximum Y value                                     | Yes      |
| Side      | Y-axis scale side (LEFT or RIGHT, defaults to LEFT) | No       |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
MANUAL_Y_AXIS_SCALE -10 10 LEFT
{% endhighlight %}

### MANUAL_X_AXIS_SCALE

The MANUAL_X_AXIS_SCALE keyword is used to set (and fix) the X-axis scale on a plot. If the x-axis scale is not set, the plot will auto-scale based upon the contents. Note that this parameter applies only to XY and SINGLEXY plots. This keyword applies to the most recently defined plot in the configuration file.

| Parameter | Description     | Required |
| --------- | --------------- | -------- |
| X min     | Minimum X value | Yes      |
| X max     | Maximum x value | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT XY
MANUAL_X_AXIS_SCALE -10 10
{% endhighlight %}

### MANUAL_X_GRID_LINE_SCALE

The MANUAL_X_GRID_LINE_SCALE keyword is used to set the x grid line scale for a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter         | Description | Required |
| ----------------- | ----------- | -------- |
| X grid line scale | Scale value | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
MANUAL_X_GRID_LINE_SCALE 2
{% endhighlight %}

### MANUAL_Y_GRID_LINE_SCALE

The MANUAL_Y_GRID_LINE_SCALE keyword is used to set the y grid line scale for a plot. This keyword applies to the most recently defined plot in the configuration file.

| Parameter         | Description | Required |
| ----------------- | ----------- | -------- |
| Y grid line scale | Scale value | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
MANUAL_Y_GRID_LINE_SCALE 2
{% endhighlight %}

### UNIX_EPOCH_X_VALUES

The UNIX_EPOCH_X_VALUES keyword is used to enable conversion of x-axis values into timestamps, assuming that the x-axis values are seconds since the Unix epoch. This keyword applies to the most recently defined plot in the configuration file.

| Parameter           | Description                                      | Required |
| ------------------- | ------------------------------------------------ | -------- |
| Unix Epoch X values | Convert X values into timestamps (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
UNIX_EPOCH_X_VALUES TRUE
{% endhighlight %}

### UTC_TIME

The UTC_TIME keyword is used to indicate that timestamps on a plot should be displayed in UTC. If this keyword is not used, timestamps will be displayed in local time. This keyword applies to the most recently defined plot in the configuration file.

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
UTC_TIME
{% endhighlight %}

## Data Object Keywords

### DATA_OBJECT

The DATA_OBJECT keyword is used to define a new data object in Telemetry Grapher. The data object will be added to the most recently defined plot in the configuration file.

| Parameter        | Description                                                           | Required |
| ---------------- | --------------------------------------------------------------------- | -------- |
| Data object type | Type of data object that will be created (LINEGRAPH, SINGLEXY or XY). | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
{% endhighlight %}

### COLOR

The COLOR keyword is used to set the color for the data object when displayed on the plot. This keyword applies to the most recently defined data object in the configuration file. This keyword is valid for all data object types.

| Parameter | Description                                                                                                                                              | Required |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Color     | Data object color (BLUE, RED, GREEN, DARKORANGE, GOLD, PURPLE, HOTPINK, LIME, CORNFLOWERBLUE, BROWN, CORAL, CRIMSON, INDIGO, TAN, LIGHTBLUE, CYAN, PERU) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
COLOR BLUE
{% endhighlight %}

### TIME_ITEM

The TIME_ITEM keyword is used to define the telemetry item that will be used as the time for a data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is valid for all data object types.

| Parameter | Description                     | Required |
| --------- | ------------------------------- | -------- |
| Item Name | Name of the time telemetry item | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
TIME_ITEM PACKET_TIMESECONDS
{% endhighlight %}

### ITEM

The ITEM keyword is used to define the telemetry item associated with a HOUSEKEEPING data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter   | Description                  | Required |
| ----------- | ---------------------------- | -------- |
| Target Name | Name of the telemetry target | Yes      |
| Packet Name | Name of the telemetry packet | Yes      |
| Item Name   | Name of the telemetry item   | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
ITEM INST HEALTH_STATUS TEMP1
{% endhighlight %}

### FORMATTED_TIME_ITEM

The FORMATTED_TIME_ITEM keyword is used to define a telemetry item that will be used to display a formatted time for a data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter | Description                               | Required |
| --------- | ----------------------------------------- | -------- |
| Item Name | Name of the formatted time telemetry item | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
FORMATTED_TIME_ITEM PACKET_TIMESECONDS
{% endhighlight %}

### VALUE_TYPE

The VALUE_TYPE keyword is used to indicate whether the telemetry item specified by the ITEM keyword should be graphed using RAW or CONVERTED values. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter  | Description                   | Required |
| ---------- | ----------------------------- | -------- |
| Value Type | Value Type (RAW or CONVERTED) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
VALUE_TYPE CONVERTED
{% endhighlight %}

### ANALYSIS

The ANALYSIS keyword is used to define an anslysis to be performed upon the telemetry item associated with a data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter     | Description                                                                                                                           | Required |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Analysis Type | Analysis to be performed (NONE, DIFFERENCE, WINDOWED_MEAN, WINDOWED_MEAN_REMOVED, STD_DEV, ALLAN_DEV, MAXIMUM, MINIMUM, PEAK_TO_PEAK) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
ANALYSIS NONE
{% endhighlight %}

### ANALYSIS_SAMPLES

The ANALYSIS_SAMPLES keyword is used to define the number of samples to be used for analysis operations specified by the ANALYSIS keyword. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter        | Description                                              | Required |
| ---------------- | -------------------------------------------------------- | -------- |
| Analysis Samples | Number of samples to be used in the analysis calculation | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
ANALYSIS MAXIMUM
ANALYSIS_SAMPLES 20
{% endhighlight %}

### SHOW_LIMITS_LINES

The SHOW_LIMITS_LINES keyword is used to enable or disable display of the limits lines for a data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter         | Description                      | Required |
| ----------------- | -------------------------------- | -------- |
| Show Limits Lines | Show limit lines (TRUE or FALSE) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
SHOW_LIMITS_LINES TRUE
{% endhighlight %}

### HORIZONTAL_LINE

The HORIZONTAL_LINE keyword can be used to add a fixed horizontal line to the plot. This keyword can be used multiple times to add more than one line. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter | Description                                                                                              | Required |
| --------- | -------------------------------------------------------------------------------------------------------- | -------- |
| Y Value   | Position on the y-axis where the line will be added                                                      | Yes      |
| Color     | Color that will be used for the horizontal line (see the COLOR keyword for the list of supported colors) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
HORIZONTAL_LINE 10 LIME
{% endhighlight %}

### Y_OFFSET

The Y_OFFSET keyword can be used to apply a fixed offset to a data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter | Description          | Required |
| --------- | -------------------- | -------- |
| Y offset  | Offset to be applied | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
Y_OFFSET 100
{% endhighlight %}

### Y_AXIS

The Y_AXIS keyword can be used to associate a data object with a plot's left or right y-axis. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for HOUSEKEEPING data objects.

| Parameter | Description            | Required |
| --------- | ---------------------- | -------- |
| Y axis    | Y axis (LEFT or RIGHT) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT HOUSEKEEPING
Y_AXIS LEFT
{% endhighlight %}

### TARGET

The TARGET keyword is used to specify the target associated with a SINGLEXY or XY data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter   | Description                  | Required |
| ----------- | ---------------------------- | -------- |
| Target Name | Name of the telemetry target | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
TARGET INST
{% endhighlight %}

### PACKET

The PACKET keyword is used to specify the packet associated with a SINGLEXY or XY data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter   | Description                  | Required |
| ----------- | ---------------------------- | -------- |
| Packet Name | Name of the telemetry packet | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
PACKET ADCS
{% endhighlight %}

### X_ITEM

The X_ITEM keyword is used to specify the telemetry item associated with the x-axis for a SINGLEXY or XY data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter | Description                | Required |
| --------- | -------------------------- | -------- |
| Item Name | Name of the telemetry item | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
X_ITEM POSX
{% endhighlight %}

### Y_ITEM

The Y_ITEM keyword is used to specify the telemetry item associated with the y-axis for a SINGLEXY or XY data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter | Description                | Required |
| --------- | -------------------------- | -------- |
| Item Name | Name of the telemetry item | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
Y_ITEM POSY
{% endhighlight %}

### Y_ITEM

The Y_ITEM keyword is used to specify the telemetry item associated with the y-axis for a SINGLEXY or XY data object. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter | Description                | Required |
| --------- | -------------------------- | -------- |
| Item Name | Name of the telemetry item | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
Y_ITEM POSY
{% endhighlight %}

### X_VALUE_TYPE

The X_VALUE_TYPE keyword is used to indicate whether the telemetry item specified by the X_ITEM keyword should be graphed using RAW or CONVERTED values. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter  | Description                   | Required |
| ---------- | ----------------------------- | -------- |
| Value Type | Value Type (RAW or CONVERTED) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
X_VALUE_TYPE CONVERTED
{% endhighlight %}

### Y_VALUE_TYPE

The Y_VALUE_TYPE keyword is used to indicate whether the telemetry item specified by the Y_ITEM keyword should be graphed using RAW or CONVERTED values. This keyword applies to the most recently defined data object in the configuration file. This keyword is only valid for SINGLEXY or XY data objects.

| Parameter  | Description                   | Required |
| ---------- | ----------------------------- | -------- |
| Value Type | Value Type (RAW or CONVERTED) | Yes      |

Example Usage:
{% highlight bash %}
TAB "Tab Title"
PLOT LINEGRAPH
DATA_OBJECT SINGLEXY
Y_VALUE_TYPE CONVERTED
{% endhighlight %}
