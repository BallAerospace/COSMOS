---
layout: news_item
title: 'ERB Config Files'
date: 2016-09-12 00:00:00 -0700
author: jmthomas
categories: [post]
---

COSMOS configuration files support ERB (Embedded RuBy) which is used heavily by [Ruby on Rails](http://rubyonrails.org/). I found a pretty good description of ERB [here](http://www.stuartellis.eu/articles/erb/). ERB allows you to put executable Ruby code in your configuration files. The trick is to surround the Ruby code with the special markers: ```<% <code> %>```. If you want the result of your Ruby code to be placed in the configuration file you need to add the equal sign to the first marker: ```<%= <code> %>```

A COSMOS user recently asked if he could include environment variables in his COSMOS configuration. This is very easy using the ERB syntax. For example, you have an environment variable named "LOG_DIR" in your system which points to the path you want to store your COSMOS logs. To use this value you would modify your system.txt file as follows:

```
...
# Paths
PATH LOGS <%= ENV["LOG_DIR"] %>
...
```

When this file gets parsed by COSMOS, the value of the LOG_DIR environment variable gets inserted into the system.txt output file. Note the %= syntax to insert the value and how I'm using the [ENV](https://ruby-doc.org/core-2.3.0/ENV.html) from the Ruby core library.

It's recommended that you don't put too much logic in these ERB statements to keep your configuration files readable and maintainable. If you have a complex piece of code you want to use in an ERB statement, you can create a utility in your 'lib' folder and define methods to use. For example, in your 'lib' folder create utilties.rb:

{% highlight ruby %}
def log_path
  File.join(Cosmos::USERPATH, 'outputs', 'mylogs')
end
{% endhighlight %}

Now in system.txt we can use that 'log_path' routine after we first require 'utilities'.

```
<% require 'utilities' %>
...
# Paths
PATH LOGS <%= log_path() %>
...
```
Notice how the first ERB statement does NOT use the %= syntax since I'm simply requiring the file I want to use. I don't want to put anything in the template itself. Later in the PATH statement I use the %= syntax to insert the result of the log_path() method.

ERB templates are particularly useful in command and telemetry definitions as they allow you to reuse sections. We've added our own routine called 'render' (similar to Ruby on Rails) which can render a command or telemetry template. The best example of this is in the COSMOS Demo INST target. If you open the inst_cmds.txt file you'll see this:

```
COMMAND INST COLLECT BIG_ENDIAN "Starts a collect on the instrument"
  <%= render "_ccsds_cmd.txt", locals: {id: 1} %>
  PARAMETER    TYPE           64  16  UINT MIN MAX 0 "Collect type"
    REQUIRED
    STATE NORMAL  0
    STATE SPECIAL 1 HAZARDOUS
  PARAMETER    DURATION       80  32  FLOAT 0.0 10.0 1.0 "Collect duration"
  PARAMETER    OPCODE        112   8  UINT 0x0 0xFF 0xAB "Collect opcode"
    FORMAT_STRING "0x%0X"
  PARAMETER    TEMP          120  32  FLOAT 0.0 25.0 0.0 "Collect temperature"
    UNITS Celcius C

COMMAND INST ABORT BIG_ENDIAN "Aborts a collect on the instrument"
  <%= render "_ccsds_cmd.txt", locals: {id: 2} %>

...
```

Notice the call to ```<%= render "_ccsds_cmd.txt", locals: {id: 1} %>```. Opening the '_ccsds_cmd.txt' file reveals this command template:

```
  PARAMETER    CCSDSVER        0   3  UINT  0     0   0 "CCSDS primary header version number"
  PARAMETER    CCSDSTYPE       3   1  UINT  1     1   1 "CCSDS primary header packet type"
  PARAMETER    CCSDSSHF        4   1  UINT  0     0   0 "CCSDS primary header secondary header flag"
  ID_PARAMETER CCSDSAPID       5  11  UINT  0  2047 999 "CCSDS primary header application id"
  PARAMETER    CCSDSSEQFLAGS  16   2  UINT  3     3   3 "CCSDS primary header sequence flags"
  PARAMETER    CCSDSSEQCNT    18  14  UINT  0 16383   0 "CCSDS primary header sequence count"
    OVERFLOW TRUNCATE
  PARAMETER    CCSDSLENGTH    32  16  UINT MIN MAX 12 "CCSDS primary header packet length"
  ID_PARAMETER PKTID          48  16  UINT MIN MAX <%= id %> "Packet id"
```

The call to render replaces everything in the named template with the render call. We follow the Ruby on Rails convention of naming these templates (Rails calls them 'partials') with a leading underscore to differentiate them from full command and telemetry definitions. Notice too that we are passing local variables to the template. The 'id: 1' syntax is basically setting the 'id' variable in the template to 1. This allows us to send a different PKTID to each command.

ERB is incredibly powerful and a great way to avoid WET (Write Each Time) command and telemetry definitions. Now go DRY (Don't Repeat Yourself) up your COSMOS configuration!

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
