---
layout: docs
title: Getting Started
---

Welcome to the COSMOS system... Let's get started! This guide is a high level overview that will help with setting up your first COSMOS project.

1. Get COSMOS Installed onto your computer by following the [Installation Guide](/docs/installation).
   - You should now have COSMOS installed and a Demo project available that we can make changes to.
2. Browse to http://localhost:8080
   - The COSMOS Command and Telemetry Server will appear. This tool provides real-time information about each "target" in the system. Targets are external systems that receive commands and generate telemetry, often over ethernet or serial connections.
3. Experiment with other COSMOS tools.
   - Use Command Sender to send individual commands.
   - Use Limits Monitor to watch for telemetry limits violations
   - Run some of the example scripts in Script Runner and Test Runner
   - View individual Telemetry packets in Packet Viewer
   - View detailed telemetry displays in Telemetry Viewer
   - Graph some data in Telemetry Grapher
   - View log type data in Data Viewer
   - Process log data with Data Extractor

## Interfacing with Your Hardware

Playing with the COSMOS Demo is fun and all, but now you want to talk to your own real hardware? Let's do it!

<div class="note unreleased">
  <p>These instructions need to be updated for COSMOS 5</p>
</div>

1.. The first step is to create a "target folder" for your new target. At a minimum this folder will contain all the information defining the packets (command and telemetry) that are needed to communicate with your hardware.

- Inside your demo area, create a folder for your target in config/targets/. The folder name should be ALL CAPS and concise. Let's pretend we're going to interface with custom piece of software you wrote called BOB, so we'll call the folder config/targets/BOB.

  2.. Next we need to define the commands and telemetry packets for our target. The details on the command and telemetry definition file formats can be found here: [Command](/docs/command) and [Telemetry](/docs/telemetry)

- Create the folder config/targets/BOB/cmd_tlm
- Create a new text file called config/targets/BOB/cmd_tlm/bob_cmds.txt with the following contents:

{% highlight bash %}
COMMAND BOB COLLECT BIG_ENDIAN "Collect temperatures"
APPEND_PARAMETER LENGTH 32 UINT 0 1024 5 "Packet Length"
APPEND_ID_PARAMETER CMD_ID 8 UINT 1 1 1 "Command Id"
APPEND_PARAMETER MODE 32 INT 0 1 0 "Temperature Collection Mode"
STATE NORMAL 0
STATE FAST 1
{% endhighlight %}

- Woah, what did we just do!
  - We created a COMMAND for target BOB named COLLECT.
  - The command is made up of BIG_ENDIAN parameters and is described by "Collect temperatures". Here we are using the append flavor of defining parameters which stacks them back to back as it builds up the packet and you don't have to worry about defining the bit offset into the packet.
  - First we APPEND_PARAMETER a parameter called LENGTH that is a 32-bit unsigned integer (UINT) that has a minimum value of 0, a maximum value of 1024, and a default value of 5.
  - Then we APPEND_ID_PARAMETER a parameter that is used to identify the packet called CMD_ID that is an 8-bit unsigned integer (UINT) with a minimum value of 1, a maximum value of 1, and a default value of 1, that is described as the "Command Id".
  - Then we APPEND_PARAMETER a third parameter called MODE which is a 32-bit integer (INT) with a minimum value of 0, a maximum value of 1, and a default value of 0, that is described as the "Temperature Collection Mode". MODE has two states which are just a fancy way of giving meaning to the integer values 0 and 1. The STATE NORMAL has a value of 0 and the STATE FAST has a value of 1.
- In summary we defined a 72-bit command packet made up of three parameters, LENGTH which tells us the length of the packet in bytes not included itself, CMD_ID which is used to identify the command, and MODE which has two values NORMAL and FAST.
- Onto telemetry, Create a new text file called config/targets/BOB/cmd_tlm/bob_tlm.txt with the following contents:

{% highlight bash %}
TELEMETRY BOB TEMPS BIG_ENDIAN "Temperature Telemetry"
ITEM LENGTH 0 32 UINT "Packet Length"
ID_ITEM TLM_ID 32 32 INT 3 "Message Identifier"
ITEM TEMP1 64 32 FLOAT "Temperature 1"
ITEM TEMP2 96 32 FLOAT "Temperature 2"
{% endhighlight %}

- This time we created a TELEMETRY packet for target BOB called TEMPS that contains BIG\*ENDIAN items and is described as "Temperature Telemetry". Unlike above, in this example I am not using the APPEND flavor of defining items so each item contains both a bit offset and a bit size. In general, if creating configuration files by hand I recommend using the APPEND versions as they are much easier to maintain.

  - So we start by defining an item called LENGTH at bit offset 0 with a bit size of 32 bits of type UINT (unsigned integer) described as "Packet Length".
    \_ Next an ID_ITEM called TLM_ID at bit offset 32 with a bit size of 32 bits of type INT (integer) with an id value of 3 and described as "Message Identifier". Id items are used to take unidentified blobs of bytes and determine which packet they are. In this case if a blob comes in with a value of 3 at bit offset 32 interpreted as a 32-bit integer then this packet will be "identified". Note the first packet defined without any ID_ITEMS is a "catch-all" packet that matches all incoming data (even if the data lengths don't match). \* Next we define two items that are temperatures. The first at bit offset 64 that is a 32-bit FLOAT and the second at bit offset 96 which is also a 32-bit float.

    3.. We have successfully defined the commands and telemetry packets for our target. Most targets will obviously have more than one command and one telemetry packet. Before we move on, now is a great time to look at the contents of some of the other target folders in config/target that come with COSMOS. They provide good examples of what the configuration for other types of targets might look like and use a lot of the available keywords for the configuration files.

    4.. Next we need to tell COSMOS that our new target BOB exists. We do that in the config/system/system.txt file. Edit this file and add the following line. See [System Configuration Guide](/docs/system):

{% highlight bash %}
DECLARE_TARGET BOB
{% endhighlight %}

- This tells COSMOS to look for a folder called BOB in config/targets.

  5.. Now we need to configure how to communicate with BOB. BOB is acting as a TCP/IP server at 192.168.1.5 and is listening on port 8888. We tell COSMOS how to talk to it by adding the following snippet to config/tools/cmd_tlm_server/cmd_tlm_server.txt. See [System Configuration Guide](/docs/system):

{% highlight bash %}
INTERFACE BOB_INT tcpip_client_interface.rb 192.168.1.5 8888 8888 5.0 nil LENGTH 0 32 4
TARGET BOB
{% endhighlight %}

- This tells COSMOS there is a new INTERFACE called BOB_INT that will connect as a TCP/IP client using the code in tcpip_client_interface.rb to address 192.168.1.5 using port 8888 for both reading and writing. It also has a write timeout of 5 seconds, reads will never timeout (nil). The TCP/IP stream will be interpreted using the COSMOS LENGTH protocol with the length field found at bit offset 0 with bit size of 32-bits and a value offset of 4 bytes (because the value in the length field does not include itself). For all the details on how to configure COSMOS interfaces please see the [Interface Guide](/docs/interfaces). The TARGET BOB line tells COSMOS that it will receive telemetry from and send commands to BOB using the BOB_INT interface.

  6.. COSMOS is now fully configured with everything needed to talk to our new target. Other things you might like to do at this point is define telemetry screens in config/targets/BOB/screens. See [Telemetry Screen Configuration](/docs/screens). Configure LENGTH and CMD_ID as IGNORED_PARAMETER in config/targets/BOB/target.txt.

  7.. That's all there is to it! In 14 lines of configuration we now have a fully configured system that is capable of connecting to, receiving telemetry from, sending commands to, displaying/graphing/logging data from our new target!
