---
layout: docs
title: Command and Telemetry Server
toc: true
---

## Introduction

The Command and Telemetry Server application provides status about the [interfaces](/docs/v5/interfaces) and targets instantiated in your COSMOS installation. Intefaces can be connected or disconnected and raw byte counts are returned. The application also provides quick shortcuts to view
both raw and formatted command and telemetry packets as they go through the COSMOS system.

![Cmd Tlm Server](/img/v5/cmd_tlm_server/cmd_tlm_server.png)

## Command and Telemetry Server Menus

### File Menu Items

The Command and Telemetry Server has one menu under File -> Options:

![File Menu](/img/v5/cmd_tlm_server/file_menu.png)

This dialog changes the refresh rate of the Command and Telemetry Server to reduce load on both your browser window and the backend server. Note that this changes the refresh rate of the various tabs in the application. The Log Messages will continue to update as messages are generated.

## Interfaces Tab

The Interfaces tab displays all the interfaces defined by your COSMOS installation. You can Connect or Disconnect interfaces and view raw byte and packet counts.

![Interfaces](/img/v5/cmd_tlm_server/interfaces.png)

## Targets Tab

The Targets tab displays aggregate informatation about individual targets.

<div class="note unreleased">
  <p>Note: This tab is not fully functional yet.</p>
</div>

![Targets](/img/v5/cmd_tlm_server/targets.png)

## Command Packets Tab

The Command Packets tab displays all the available commands. The table can be sorted by clicking on the column headers.

![Commands](/img/v5/cmd_tlm_server/commands.png)

Clicking on View Raw opens a dialog displaying the raw bytes for that command.

![Raw Command](/img/v5/cmd_tlm_server/raw_command.png)

Clicking View in Command Sender opens up a new [Command Sender](/docs/v5/cmd-sender) window with the specified command.

## Telemetry Packets Tab

The Telemetry Packets tab displays all the available telemetry. The table can be sorted by clicking on the column headers.

![Telemetry](/img/v5/cmd_tlm_server/telemetry.png)

Clicking on View Raw opens a dialog displaying the raw bytes for that telemetry packet.

![Raw Telemetry](/img/v5/cmd_tlm_server/raw_telemetry.png)

Clicking View in Command Sender opens up a new [Packet Viewer](/docs/v5/packet-viewer) window with the specified telemetry packet.

## Status Tab

The Status tab displays the current COSMOS Limits Set, server API statistics, and Background tasks.

<div class="note unreleased">
  <p>Note: This tab is not fully functional yet.</p>
</div>

![Status](/img/v5/cmd_tlm_server/status.png)

## Log Messages

The Log Messages table sits below all the tabs in the Command and Telemetry Server application. It displays server messages such as limits events (new RED, YELLOW, GREEN values), logging events (new files) and interface events (connecting and disconnecting). It can be filtered by entering values in the Search box.

![Log Messages](/img/v5/cmd_tlm_server/log_messages_filter.png)
