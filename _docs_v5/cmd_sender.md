---
layout: docs
title: Command Sender
toc: true
---

## Introduction

Command Sender provides the ability to send any command defined by COSMOS. Commands are selected using the Target and Packet drop down fields which populate the command parameter (if any). A command history is stored which is also editable. Commands in the command history can be re-executed by pressing Enter.

![Command Sender](/img/v5/command_sender/command_sender.png)

## Command Sender Menus

### Mode Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/command_sender/mode_menu.png"
     alt="Mode Menu"
     style="float: left; margin-right: 50px; height: 160px;" />

- Ignores parameter range checking
- Displays parameter state values in hex
- Shows ignored parameters
- Disables all parameter conversions

## Sending Commands

Select a command by first selecting the target from the Select Target drop down. Changing the target automatically updates the Select Packet options to only display commands from that target. If the command has parameters a table is generated with all the parameters.

![INST COLLECT](/img/v5/command_sender/inst_collect.png)

Clicking on a parameter with States (like TYPE in the above example) brings up a drop down to select a state. Selecting a state populates the value field next to it. Sending a command updates the Status text and the Command History.

![INST COLLECT Sent](/img/v5/command_sender/inst_collect_sent.png)

You can directly edit the Command History to change a parameter value. Pressing Enter on the line will then execute the command. If the command has changed a new line will be entered in the Command History. Pressing Enter several times on the same line updates the Status text with the number of commands sent (3 in the next example).

![INST COLLECT Sent 3](/img/v5/command_sender/inst_collect_sent_3.png)

### Hazardous Commands

Sending [hazardous](/docs/v5/command#hazardous) commands will prompt the user whether to send the command.

![INST CLEAR](/img/v5/command_sender/inst_clear.png)

Commands can also have hazardous [states](/docs/v5/command#state) (INST COLLECT with TYPE SPECIAL) which also prompt the user. In this example, we've also checked all the menu options to show ignored parameters, display state values in hex (see SPECIAL, 0x1), disabled range checking (DURATION 1000), and disabled parameter conversions.

![INST COLLECT Hazardous](/img/v5/command_sender/inst_collect_hazardous.png)

Selecting Yes will send the command and update the history with all the parameters shown.

![INST COLLECT History](/img/v5/command_sender/inst_collect_hazardous_history.png)

Note that when writing Scripts all parameters are optional unless explicitly marked [required](/docs/v5/command#required).
