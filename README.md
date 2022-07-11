## Welcome to OpenC3

> "Open Source, Open Architecture - Command, Control and Communication"

[![OpenC3 5 Playwright Tests](https://github.com/OpenC3/openc3/actions/workflows/playwright.yml/badge.svg)](https://github.com/OpenC3/openc3/actions/workflows/playwright.yml)<br/>
[![Cosmos 5 Ruby Unit Tests](https://github.com/OpenC3/openc3/actions/workflows/ruby_unit_tests.yml/badge.svg)](https://github.com/OpenC3/openc3/actions/workflows/ruby_unit_tests.yml)<br/>
[![Cosmos 5 API Tests](https://github.com/OpenC3/openc3/actions/workflows/api_tests.yml/badge.svg)](https://github.com/OpenC3/openc3/actions/workflows/api_tests.yml)<br/>
[![Code Climate](https://codeclimate.com/github/OpenC3/openc3/badges/gpa.svg)](https://codeclimate.com/github/OpenC3/openc3)<br/>
[![Codecov](https://img.shields.io/codecov/c/github/codecov/example-python.svg)](https://codecov.io/gh/OpenC3/openc3)

[Documentation](https://openc3.com)

OpenC3 provides all the functionality needed to send commands to and receive data from one or more embedded systems referred to as "targets". Out of the box functionality includes: Telemetry Display, Telemetry Graphing, Operational and Test Scripting, Command Sending, Logging, Log File Playback, and more.

So what can you use this for? We use it to test about everything we create and OpenC3 is great for automating embedded systems testing or operation. It can provide a fully featured user interface to any piece of hardware that provides an electronic way of communicating with it (TCP/IP, UDP, Serial, etc). Potential uses range from testing embedded systems, to home automation, to verifying cell phones, to helping you make that next great thing that changes the world! The sky is the limit...

After configuring OpenC3 to talk to your hardware, you immediately can use the following tools:

1. **Command and Telemetry Server**

   - This provides status of all the target connections within the OpenC3 system. It provides allows interfaces to be connected and disconnected and allows raw packet data to be viewed.

1. **Limits Monitor**

   - The Limits Monitor tool provides an overview of all telemetry points in the system that are currently out of limits. It also maintains a log of limits changes and continues to display items that have gone out of limits even after they have been restored to green status.

1. **Command Sender**

   - Command Sender allows you to manually send one-off commands with conventient drop downs and descriptions of each command and command parameter.

1. **Script Runner**

   - Script Runner allows for running OpenC3 test procedures or any other Ruby code from a graphical environment that highlights each line as it executes. At anytime during execution, the script can be paused or stopped. If a telemetry check fails or any other exception occurs, the script is immediately stopped and the user notified.

   - Script Runner also allows you to break your operational or test procedures down into discreet test cases that each complete with either SUCCESS or FAILURE. After running, a test report is automatically created for you. Convenient features such as the ability to loop testing help get the kinks out of your system before formal runs.

1. **Packet Viewer**

   - Packet Viewer provide a simple key value list of each telemetry item in the system giving you full view of the most recent realtime value of any telemetry point.

1. **Telemetry Viewer**

   - Create custom organized telemetry screens using a wide variety of available telemetry widgets for display. Provide exactly the views that your users need to see for each subsystem in you system.

1. **Telemetry Grapher**

   - Realtime and offline line graphing of telemetry points. Multiple telemetry points per graphs and multiple graphs per window allow you to efficiently organize your data. Great for graphing temperatures and voltages both in realtime and post-test.

1. **Extractor**

   - Used for offline analysis of command and telemetry data. Extracts a given list of items into a CSV file for further analysis in other tools such as Excel or Matlab.

OpenC3 is built and maintained by Ryan Melton (ryanmelt) and Jason Thomas (jmthomas) at OpenC3, Inc.

## Getting Started

1.  See the [Installation Guide](https://openc3.com/docs/v5/installation) for detailed instructions.

1.  Follow the [Getting Started](https://openc3.com/docs/v5/gettingstarted) to start developing your configuration.

## Contributing

We encourage you to contribute to OpenC3!

Contributing is easy.

1. Fork the project
2. Create a feature branch
3. Make your changes
4. Submit a pull request

YOU MUST AGREE TO THE FOLLOWING TO SUBMIT CODE TO THIS PROJECT:

FOR ALL CONTRIBUTIONS TO THE OPENC3 PROJECT, OPENC3, INC. MAINTAINS ALL RIGHTS TO ALL CODE CONTRIBUTED TO THE OPENC3 PROJECT INCLUDING THE RIGHT TO LICENSE IT UNDER OTHER TERMS.

## License

OpenC3 is released under the AGPL v3 with a few addendums. See [LICENSE.txt](LICENSE.txt)
