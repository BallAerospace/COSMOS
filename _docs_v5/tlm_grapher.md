---
layout: docs
title: Telemetry Grapher
toc: true
---

## Introduction

Packet Viewer is a live telemetry viewer which requires no configuration to display the current values for all defined target, packet, items. Items with limits are displayed colored (blue, green, yellow, or red) according to their current state. Items can be right clicked to get detailed information.

![Telemetry Grapher](/img/v5/telemetry_grapher/telemetry_grapher.png)

## Telemetry Grapher Menus

### File Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/telemetry_grapher/file_menu.png"
     alt="File Menu"
     style="float: left; margin-right: 50px; height: 80px;" />

- Open a saved configuration (plots and items)
- Save the current configuration

#### Open Configuration

The Open and Save Configuration options deserve a little more explanation. When you select File Open the Open Configuration dialog appears. It displays a list of all saved configurations (INST_TEMPS in this example). You select a configuration and then click Ok to load it. You can delete existing configurations by clicking the Trash icon next to a configuration name.

![Open Config](/img/v5/telemetry_grapher/open_config.png)

#### Save Configuration

When you select File Save the Save Configuration dialog appears. It displays a list of all saved configurations (INST_TEMPS in this example). You click the Configuration Name text field, enter the name of your new configuration, and click Ok to save. You can delete existing configurations by clicking the Trash icon next to a configuration name.

![Save Config](/img/v5/telemetry_grapher/save_config.png)

### Plot Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/telemetry_grapher/plot_menu.png"
     alt="File Menu"
     style="float: left; margin-right: 50px; height: 80px;" />

- Add a new plot
- Edit the current plot

## Selecting Items

Selecting a target from the Select Target drop down automatically updates the available packets in the Select Packet drop down which updates the available items in the Select Item drop down. Clicking Add Item adds the item to the graph which immediately beings graphing.

![Temp 1](/img/v5/telemetry_grapher/graph_temp1.png)

As time passes, the main graph fills up and starts scrolling while the overview graph at the bottom shows the entire history.

![Temp 1 History](/img/v5/telemetry_grapher/graph_temp1_time.png)

Selecting a new item and adding it to the graph automatically fills the graph with history until the beginning of the first item. This allows you to add items to the graph incrementally and maintain full history.

![Temp1 Temp2](/img/v5/telemetry_grapher/graph_temp1_temp2.png)

## Plot Window Management

All plots can be moved around the browser window by clicking their title bar and moving them. Other graphs will move around intelligently to fill the space. This allows you order the graphs no matter which order they were create in.

Each plot has a set of window buttons in the upper right corner. The first shrinks or grows the plot both horizontally and vertically to allow for 4 plots in the same browser tab. Note that half height graphs no longer show the overview graph.

![Four Plots](/img/v5/telemetry_grapher/four_plots.png)

The second button shrinks or grows the graph horizontally so it will either be half or full width of the browser window. This allows for two full width graphs on top of each other.

![Two Full Width](/img/v5/telemetry_grapher/two_full_width.png)

The second button shrinks or grows the graph vertically so it will either be half or full height of the browser window. This allows for two full height graphs side by side.

![Two Full Height](/img/v5/telemetry_grapher/two_full_height.png)

The line button minimizes the graph to effectively hide it. This allows you to focus on a single graph without losing existing graphs.

![Minimized](/img/v5/telemetry_grapher/minimized.png)

The final X button closes the graph.
