---
layout: docs
title: Script Runner
toc: true
---

## Introduction

Script Runner is both an editor of COSMOS scripts as well as executes scripts. Script files are stored within a COSMOS target and Script Runner provides the ability to open, save, download and delete these files. When a suite of scripts is opened, Script Runner provides additional options to run individial scripts, groups of scripts, or entire suites.

## Script Runner Menus

### File Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/script_runner/file_menu.png"
     alt="File Menu"
     style="float: left; margin-right: 50px; height: 250px;" />

- Clears the Script Runner editor and filename
- Opens a dialog to select a file to open
- Saves the currently opened file to disk
- Opens a dialog to allow the user to rename the current file
- Downloads the current file to the browser
- Deletes the current file (Permanently!)

#### File Open

The Open and Save Dialogs deserve a little more explanation. When you select File Open the File Open Dialog appears. Initially it displays a tree view of the installed targets. You can manually open the folders and browse for the file you want. You can also use the search box at the top and start typing part of the filename to filter the results.

![File Open Dialog](/img/v5/script_runner/file_open_check.png)

#### File Save As

When saving a file for the first time, or using File Save As, the File Save As Dialog appears. It works similar to the File Open Dialog displaying the tree view of the installed targets. You must select a folder by clicking the folder name and then filling out the Filename field with a filename before clicking Ok. You will be prompted to before over-writing an existing file.

![File Save As](/img/v5/script_runner/file_save_as.png)

### Script Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/script_runner/script_menu.png"
     alt="Script Menu"
     style="float: left; margin-right: 50px; height: 230px;" />

- Opens another page to display the currently running scripts
- Performs a Ruby Syntax check on the current file
- Shows the Call Stack of the running script (only active when running)
- Displays the Debug prompt to allow Stepping and [debugging](/docs/v5/script-runner#debugging-scripts)
- Disconnects from real interfaces for safe script [debugging](/docs/v5/script-runner#debugging-scripts)

The Running Scripts page lists the currently running scripts. This allows other users to connect to running scripts and follow along with the currently executing script.

![Running Scripts](/img/v5/script_runner/running_scripts.png)

## Running Scripts

Running a regular script is simply a matter of opening it and clicking the Start button. By default when you open a script the Filename is updated and the editor loads the script.

![checks.rb](/img/v5/script_runner/checks_rb.png)

Once you click Start the script is spawned in the Server and the Script State becomes Connecting.

![connecting](/img/v5/script_runner/connecting.png)

At that point the currently executing line is marked with green. If an error is encountered the line turns red and and the Pause button changes to Retry to allow the line to be re-tried.

![error](/img/v5/script_runner/script_error.png)

This allows checks that depend on telemetry changing to potentially be retried as telemetry is being updated live in the background. You can also click Go to continue pass the error or Stop to end the script execution.

## Running Script Suites

If a script has the word 'suite' in the filename it automatically prompts Script Runner to parse the file to populate the Suite, Group, and Script drop down menus.

![Suite Script](/img/v5/script_runner/suite_script.png)

All suite files should start with the following line:

{% highlight ruby %}
load 'cosmos/script/suite.rb'
{% endhighlight %}

### Cosmos::Group

This pulls in the COSMOS suite framework including the Cosmos::Suite and Cosmos::Group classes. Any methods starting with 'script', 'op', or 'test' which are implemented inside a Cosmos::Group class are automatically included as scripts to run. For example, in the above image, you'll notice the 'script_1_method_with_long_name' is in the Script drop down menu. Here's another simple example:

<!-- prettier-ignore -->
{% highlight ruby %}
class ExampleGroup < Cosmos::Group
  def setup
    puts "setup"
  end
  def script_1
    puts "script 1"
  end
  def teardown
    puts "teardown"
  end
end
{% endhighlight %}

The setup and teardown methods are special methods which enable the Setup and Teardown buttons next to the Group drop down menu. Clicking these buttons runs the associated method.

### Cosmos::Suite

Groups are added to Suites by creating a class inheriting from Cosmos::Suite and then calling the add_group method. For example:

<!-- prettier-ignore -->
{% highlight ruby %}
class MySuite < Cosmos::Suite
  def initialize
    super()
    add_group('ExampleGroup')
  end
  def setup
    puts "Suite setup"
  end
  def teardown
    puts "Suite teardown"
  end
end
{% endhighlight %}

Again there are setup and teardown methods which enable the Setup and Teardown buttons next to the Suite drop down menu.

Multiple Suites and Groups can be created in the same file and will be parsed and added to the drop down menus. Clicking Start at the Suite level will run ALL Groups and ALL Scripts within each Group. Similarly, clicking Start at the Group level will run all Scripts in the Group. Clicking Start next to the Script will run just the single Script.

### Script Suite Options

Opening a Script Suite creates six checkboxes which provide options to the running script.

#### Pause on Error

Pauses the script if an error is encountered. This is the default and identical to how normal scripts are executed. Unchecking this box allows the script to continue past errors without user intervention. Similar to the User clicking Go upon encountering an error.

#### Continue after Error

Continue the script if an error is encountered. This is the default and identical to how normal scripts are executed. Unchecking this box means that the script will end after the first encountered error and execution will continue with any other scripts in the Suite/Group.

#### Abort after Error

Abort the entire execution upon encountering an error. If the first Script in a Suite's Group encounters an error the entire Suite will stop execution right there.

#### Manual

Set a Ruby global variable called `$manual` to true. Setting this box only allows the script author to determine if the operator wants to execute manual steps or not. It is up the script author to use `$manual` in their scripts.

#### Loop

Loop whatever the user Started continuously. If the user clicks Start next to the Group then the entire Group will be looped. This is useful to catch and debug those tricky timing errors that only sometimes happen.

#### Break Loop on Error

Break the loop if an Error occurs. Only available if the Loop option is set.

## Debugging Scripts

<div class="note unreleased">
  <p>TODO</p>
</div>
