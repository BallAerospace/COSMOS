---
layout: docs
title: Limits Monitor
toc: true
---

## Introduction

The Limits Monitor application provides situational awareness for all telemetry items with limits. All limits items which violate their yellow or red limits are shown and continue to be shown until explicity dismissed. Individual items and entire packets can be manually ignored to filter out known issues. In addition, all limits events are logged in a table which can be searched.

![Cmd Tlm Server](/img/v5/limits_monitor/limits_monitor.png)

## Limits Monitor Menus

### File Menu Items

Limits Monitor has one menu under File -> Show Ignored:

![Ignored](/img/v5/limits_monitor/ignored.png)

This dialog displays all the items which the user has manually ignored by clicking the ignore icons next to out of limits items. Note that entire Packets which have been ignored are listed as TARGET PACKET without an item (as shown by INST MECH). Ignored items are removed by clicking the Trash icon. This means that the next time this item goes out of limits it will be displayed.

## Limits Tab

The main interface of Limits Monitor is the Limits tab. This is where items are displayed when they violate a yellow or red limit.

![Limits](/img/v5/limits_monitor/limits.png)

Items with limits values are displayed using a red yellow green limits bar displaying where the current value lies within the defined limits (as shown by the various TEMP items). Items with yellow or red [states](/docs/v5/telemetry#state) are simply displayed with their state color (as shown by GROUND1STATUS). The COSMOS Demo contains both INST HEALTH_STATUS TEMP2 and INST2 HEALTH_STATUS TEMP2 which are identically named items within different target packets. Limits Monitor only displays the item name to save space, however if you mouse over the value box the full target and packet name is displayed.

![Mouseover](/img/v5/limits_monitor/mouseover.png)

Clicking the first nested 'X' icon ignores the entire packet where the item resides. Any additional items in that packet which go out of limits are also ignored by Limits Monitor. Clicking the second (middle) 'X' ignores ONLY that specific item. If any packets or items are ignored the Overall Limits State is updated to indicate "(Some items ignored)" to indicate the Limits State is potentially being affected by ignored items.

Clicking the last icon (eye with strike-through) temporarily hides the specified item. This is different from ignoring an item because if this item goes out of limits it will be again be displayed. Hiding an item is useful if the item has gone back to green and you want to continue to track it but want to clean up the current list of items. For example, we might hide TEMP2 and GROUND2STATUS in the above example as they have transitioned back to green.

## Log Tab

The Log tab lists all limits events. Events can be filtered by using the Search box as shown.

![Log](/img/v5/limits_monitor/log.png)
