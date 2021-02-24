---
layout: news_item
title: "COSMOS Cmd/Tlm Naming"
date: 2016-07-06 17:00:00 -0700
author: jmthomas
categories: [post]
---

Recently a user asked if they could add exclamation points and question marks to their command and telemetry items. Absolutely! COSMOS provides great flexibility in command and telemetry naming conventions. (See [Command](http://cosmosrb.com/docs/v4/command)). For example, adding an exclamation point to a command to denote a more severe version of the same command:

```
COMMAND TGT ABORT BIG_ENDIAN "Tries to abort a collect on the instrument"
COMMAND TGT ABORT! BIG_ENDIAN "Force aborts a collect on the instrument"
```

While it doesn't make sense to define a command with a question mark, it works well with telemetry points. For example, there is a telemetry point which indicates whether a mechanism is deployed or not. It is an analog value that indicates deployed if the value is above zero. To view both the raw value and the deployed status, define a derived telemetry point which indicates a TRUE or FALSE status:

```
APPEND_ITEM DEPLOYED 16 UINT "Deployed raw value"
ITEM DEPLOYED? 0 0 DERIVED "Deployed status"
  STATE FALSE 0
  STATE TRUE 1
  GENERIC_READ_CONVERSION_START UINT 8
    myself.read('DEPLOYED') > 0 ? 1 : 0
  GENERIC_READ_CONVERSION_END
```

Note that this is probably overkill in this case because the conversion could just as easily be applied directly to the item. The raw value could then be obtained by calling tlm_raw("TGT PKT DEPLOYED") (see [tlm_raw](http://cosmosrb.com/docs/scripting#tlmraw)).

These practices are similar to the Ruby convention of using methods with an exclamation point (bang) to indicate a dangerous method which typically directly modifies its caller. Ruby also has a convention of methods with question marks returning a boolean true or false value. Read more in the [Ruby documentation](http://docs.ruby-lang.org/en/trunk/syntax/methods_rdoc.html).
