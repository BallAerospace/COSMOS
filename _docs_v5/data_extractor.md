---
layout: docs
title: Data Extractor
toc: true
---

## Introduction

Data Extractor extracts command and telemetry items into comma or tab separated files. Individual items or entire packets can be processed over any time period. Data Extractor also has a number of options to control the output for post processing in Excel or Matlab, for example.

## Data Extractor Menus

### File Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/data_extractor/file_menu.png"
     alt="File Menu"
     style="float: left; margin-right: 50px; height: 160px;" />

- Opens a saved configuration
- Save the current configuration (item list)
- Delimit output with commas
- Delimit output with tabs

#### Open Configuration

The Open and Save Configuration options deserve a little more explanation. When you select File Open the Open Configuration dialog appears. It displays a list of all saved configurations (INST_TEMPS in this example). You select a configuration and then click Ok to load it. You can delete existing configurations by clicking the Trash icon next to a configuration name.

![Open Config](/img/v5/data_extractor/open_config.png)

#### Save Configuration

When you select File Save the Save Configuration dialog appears. It displays a list of all saved configurations (INST_TEMPS in this example). You click the Configuration Name text field, enter the name of your new configuration, and click Ok to save. You can delete existing configurations by clicking the Trash icon next to a configuration name.

![Save Config](/img/v5/data_extractor/save_config.png)

### Mode Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/data_extractor/mode_menu.png"
     alt="Mode Menu"
     style="float: left; margin-right: 50px; height: 250px;" />

- Skip ignored items when [adding](/docs/v5/data-extractor#adding-targets-packets-items) targets or packets
- Fill empty cells with the previous value
- Add a Matlab comment ('%') to the header
- Only output changed values
- Only list item name as column header
- List full Target Packet Item as header

## Selecting Items for Output

### Start/End Date/Time

Data Extractor provides text fields where you specify the time range to extract items. Clicking the Start Date and End Date text fields opens a Date Chooser dialog. Note you can also manually type in the date.

![Date Chooser](/img/v5/data_extractor/date_chooser.png)

Start Time and End Time are simple text fields. If you enter an invalid time, Data Extractor will warn you and indicate the correct syntax.

![Time Validation](/img/v5/data_extractor/time_validation.png)

### Adding Targets Packets Items

Data Extractor provides Target, Packet, Item drop downs to select the items you want to export. When you select a Target the Packet drop down defaults to \[All\] which sets the button to "Add Target". This would add EVERY item defined in EVERY packet in the target. NOTE: This can be a LOT of telemetry points but any added point can be removed.

![Select Target](/img/v5/data_extractor/select_target.png)

When you select a Packet the Item drop down defaults to \[All\] which sets the button to "Add Packet". This would add EVERY item defined in the specified packet. NOTE: This can be a LOT of telemetry points but any added point can be removed.

![Select Packet](/img/v5/data_extractor/select_packet.png)

When you select an individual Item the button changes to "Add Item" and the Description field updates with the item's description.

![Select Item](/img/v5/data_extractor/select_item.png)

### Removing Items

Once you've added items the Items table will have a list of items.

![Items Table](/img/v5/data_extractor/items_table.png)

Items can be removed by clicking the Trash icon next to the item. ALL items can be removed by clicking the Trash icon in the header.

![Delete All Mouseover](/img/v5/data_extractor/delete_all_mouseover.png)

### Editing Items

Items can be edited by clicking the Pencil icon next to the item. ALL items can be edited by clicking the pencil icon in the header.

![Edit All Mouseover](/img/v5/data_extractor/edit_all_mouseover.png)

Clicking the Edit All brings up the Edit All Items dialog.

![Edit All](/img/v5/data_extractor/edit_all_items.png)

This allows you to change the data type of all items in the list. In this example we change from the default of CONVERTED to RAW. This updates the item list as follows.

![Items Table Raw](/img/v5/data_extractor/items_table_raw.png)

Clicking the pencil next to an individual item brings up a similar dialog.

![Edit TEMP1](/img/v5/data_extractor/edit_temp1.png)

If we change TEMP1 back to CONVERTED the item list is again updated. Note that (CONVERTED) is not shown as this is the default output.

![Edit TEMP1](/img/v5/data_extractor/items_table_temp1.png)

## Processing Items

Clicking the Process button starts the processing of the items list. A progress bar is shown above the table and the Process button changes to Cancel to allow cancelling the process.

![Processing](/img/v5/data_extractor/processing.png)

When the processing is complete, the browser shows a file download link. Note this varies by browser. This example is from Chrome.

![Download](/img/v5/data_extractor/download.png)
