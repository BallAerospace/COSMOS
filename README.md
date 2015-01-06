## Welcome to Ball Aerospace COSMOS

> "The User Interface for Embedded Systems"

[Documentation](https://github.com/BallAerospace/COSMOS/wiki)

Ball Aerospace COSMOS provides all the functionality needed to send commands to and receive data from one or more embedded systems referred to as "targets". Out of the box functionality includes: Telemetry Display, Telemetry Graphing, Operational and Test Scripting, Command Sending, Logging, Log File Playback, Table Management, and more.

So what can you use this for?  We use it to test about everything we create and COSMOS is great for automating any system of embedded systems. It can provide a fully featured user interface to any piece of hardware that provides an electronic way of communicating with it (TCP/IP, UDP, Serial, etc).  Potential uses range from testing embedded systems, to home automation, to verifying cell phones, to helping you make that next great thing that changes the world!  The sky is the limit...

After configuring COSMOS to talk to your hardware, you immediately can use the following 15 tools:

1. **Command and Telemetry Server**
    * This is the heart of the realtime functionality within the Ball Aerospace COSMOS system.  It maintains realtime connections to each target in your system and is the single point for all outgoing commands and incoming telemetry packets.  By default, it logs all commands and telemetry sent/received for later review and analysis.  The Command and Telemetry Server also monitors limits on all telemetry packets received.

1. **Replay**
    * Replay masquerades as the Command and Telemetry Server but it sources telemetry packets from telemetry log files instead of realtime streams. VCR style controls are provided to move backwards and forwards through telemetry logs and play them back into the other COSMOS realtime tools.  Especially useful with Telemetry Viewer.  Cannot be used at the same time as the Command and Telemetry Server (at least on the same computer).

1. **Limits Monitor**
    * The Limits Monitor tool provides an overview of all telemetry points in the system that are currently out of limits.  It also maintains a log of limits changes and continues to display items that have gone out of limits even after they have been restored to green status.

1. **Command Sender**
    * Command Sender allows you to manually send one-off commands with conventient drop downs and descriptions of each command and command parameter.

1. **Script Runner**
    * Script Runner allows for running COSMOS test procedures or any other Ruby code from a graphical environment that highlights each line as it executes. At anytime during execution, the script can be paused or stopped. If a telemetry check fails or any other exception occurs, the script is immediately stopped and the user notified. Built-in code completion makes writing COSMOS scripts easy.

1. **Test Runner**
    * Operations and formal testing meet the unit test framework paradigm.   Test Runner allows you to break your operational or test procedures down into discreet test cases that each complete with either SUCCESS or FAILURE.  After running, a test report is automatically created for you.  Convenient features such as the ability to loop testing help get the kinks out of your system before formal runs.

1. **Packet Viewer**
    * Packet Viewer provide a simple key value list of each telemetry item in the system giving you full view of the most recent realtime value of any telemetry point.

1. **Telemetry Viewer**
    * Create custom organized telemetry screens using a wide variety of available telemetry widgets for display.  Provide exactly the views that your users need to see for each subsystem in you system.

1. **Telemetry Grapher**
    * Realtime and offline line graphing and x-y plotting of telemetry points.  Multiple telemetry points per plot, multiple plots per tab, and multiple tabs allow you to efficiently organize your data.  Great for graphing temperatures and voltages both in realtime and post-test.

1. **Data Viewer**
    * Sometimes data cannot be displayed effectively in telemety widgets or is not as useful without being able to scroll back through a history of values.  Data Viewer is used to provide a textual display of telemetry items and packets with scrollable history.  It provides a great display for log messages, events, memory dumps, and other forms of data that don't fit well into the other display options.

1. **Telemetry Extractor**
    * Used for offline analysis of telemetry log files.  Telemetry Extracts extracts a given list of telemetry items from a telemetry log file into a CSV file for further analysis in other tools such as Excel or Matlab.

1. **Command Extractor**
    * Used for offline analysis of command log files.  Takes binary command log files and converts them into human readable text.

1. **Handbook Creator**
    * Creates Command and Telemetry Handbooks using the information in the COSMOS configuration files in both HTML and PDF formats.  This provides a more human readable reference document to give to people who want to use a COSMOS system.

1. **Table Manager**
    * Table Manager provides a graphical binary file editor that provides a convenient method for creating and modifying binary configuration files/tables.

1. **OpenGL Builder**
    * OpenGL Builder helps in building 3d scenes of objects made of STL (stereolithography) files that can then be used within custom written COSMOS applications where they can be animated or change color based on telemetry.

COSMOS is built and maintained by Ryan Melton (ryanatball/ryanmelt) and Jason Thomas (jmthomas) at Ball Aerospace & Technologies Corp.

## Getting Started

1. Install COSMOS at the command prompt if you haven't yet:

        gem install cosmos

   Note on non-windows systems you will need to have all necessary prerequisites installed (primarily cmake and qt 4.8.x). See the [Installation Guide](https://github.com/BallAerospace/COSMOS/wiki/Installation-Guide) for detailed instructions.

2. At the command prompt, create a new COSMOS project:

        cosmos demo test

   where "test" is the application name.

3. Change directory to `test` and start the COSMOS Launcher:

        cd test
        ruby Launcher

   Run with `--help` or `-h` for options.

4. Click on the various tools to start experimenting with COSMOS!

5. Follow the [Documentation](https://github.com/BallAerospace/COSMOS/wiki) to start developing your configuration.

## Contributing

We encourage you to contribute to COSMOS!

Contributing is easy.

1. Fork the project
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Before any contributions can be incorporated we do require all contributors to sign a Contributor License Agreement here:
[Contributor License Agreement](https://docs.google.com/forms/d/1ppnHUSXtY1GRTNPIyUaB1OYHbW5Ca67GFMgMRPBG8u0/viewform)

This protects both you and us and you retain full rights to any code you write.

## Code Status

* [![Build Status](https://travis-ci.org/BallAerospace/COSMOS.svg?branch=master)](https://travis-ci.org/BallAerospace/COSMOS)

## License

Ball Aerospace COSMOS is released under the GPLv3.0 with a few addendums.   See [LICENSE.txt](LICENSE.txt)
