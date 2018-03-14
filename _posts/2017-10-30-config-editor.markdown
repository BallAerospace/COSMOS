---
layout: news_item
title: 'Config Editor'
date: 2017-10-30 09:00:00 -0700
author: jmthomas
categories: [post]
---
COSMOS gained a new tool in the [4.0.0 release](/news/2017/08/04/cosmos-4-0-0-released/) called Configuration Editor. This tool provides contextual help when editing COSMOS configuration files and thus should make configuring COSMOS much easier than in the past.

### Configuration Editor Basics

When creating a new project from from the Demo you'll notice a new icon in the Launcher under the Utilities label:

![Demo Launcher](/img/2017_10_30_demo_launcher.png)

Note that as of this post the Install Launcher does not have the new Configuration Editor or Command Sequence buttons but this will be addressed in the next release.

Clicking the Config Editor button brings up the Configuration Editor tool:

![Config Editor](/img/2017_10_30_config_editor.png)

Configuration Editor has three vertical panes. The far left is a Windows Explorer type tree view which opens at the base of your COSMOS configuration. This makes it easy to see and navigate through all the COSMOS configuration files.

The middle pane is a file editor which opens files when they are clicked on in the left pane tree view.

The right pane is what Configuration Editor was created for. It provides contextual help for all the COSMOS keywords. As the editor cursor in the middle pane changes the contextual help changes to reflect current editor line. Here's an example of the right pane when the Demo's INST target's command definition is edited:

![Config Editor](/img/2017_10_30_inst_cmds.png)

The user can either edit the configuration file directly in the middle pane or use the configuration help in the right pane. Edits in the middle pane are immediately reflected in the right pane. Edits in the right pane are not reflected back in the configuration pane until the user tabs or clicks to another field. Note that tabbing through the fields is a quick way to transition from one parameter to another.

Configuration Editor contains the same Edit and Search menu options that Script Runner supports. Searching for keywords and transitioning from one to another also updates the configuration help pane which is another way to quickly check particular keywords.

### Configuration Editor Links

If you have an older (pre-4.0) COSMOS configuration or generated a basic configuration from the install (4.0.0-4.0.3) you will not have a link to the new Configuration Editor tool in your Launcher. Follow the following steps to add this tool.

1. Edit config/tools/launcher/launcher.txt
2. Add the following line (typically after Utilities LABEL)
```
TOOL "Config Editor" "LAUNCH ConfigEditor" "config_editor.png"
```

Restart your Launcher and you should see this new tool to help you configure COSMOS. Note that if you don't have the Configuration Editor button then you probably also don't have a button for the new Command Sequence tool. Add the following line after the Command Sender line to access this tool:
```
TOOL "Command Sequence" "LAUNCH CmdSequence" "cmd_sequence.png"
```

Enjoy these new COSMOS 4.0 tools!

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
