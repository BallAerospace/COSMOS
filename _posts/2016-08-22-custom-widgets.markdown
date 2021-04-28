---
layout: news_item
title: "Custom Widgets"
date: 2016-08-22 00:00:00 -0700
author: jmthomas
categories: [post]
---

Sometimes we receive requests to make custom COSMOS widgets or to modify existing COSMOS widgets to add certain looks or functionality. While this is a project we're happy to perform for our customers, it's also something that can be done by end users willing to dig into some of the Qt and COSMOS documentation. In this post, I'm going to describe how to create a custom COSMOS widget.

When asked to perform customizations like this I first bring up the COSMOS Demo. We try to include all the COSMOS features in the Demo so end users have concrete examples to follow instead of relying solely on the excellent documentation at [cosmosc2.com](http://cosmosc2.com/docs/home). Obviously you must first have COSMOS installed so follow the [installation instructions](http://cosmosc2.com/docs/v4/installation/) and then launch the Demo by running the Launcher in the Demo folder. Here is how the server appears on my Windows machine:

![COSMOS Demo Server](/img/2016_08_22_server.png)

I'm going to create a custom widget in the INST target to display some of the Array data in a table. If you first launch the Telemetry Viewer and open the INST ARRAY screen you should see the following:

![COSMOS Inst Array](/img/2016_08_22_inst_array.png)

This screen is already using the Array widget to display this data in a text box. We will add our new widget to the top of the screen which will display the data in a table. Let's add the line to the screen which will call our new widget. Edit `demo/config/targets/INST/screens/array.txt` and add the following line in the middle:

```
...
TITLE "Instrument Array Data"
DEMOTABLE INST HEALTH_STATUS ARY
ARRAY INST HEALTH_STATUS ARY 300 50 nil 8 FORMATTED
...
```

Now we need to create the DemotableWidget which will implement the actual display. Create a new file called `demotable_widget.rb` in `demo/config/targets/INST/lib`. Note that the name of the line in the config file, DEMOTABLE, must be all lowercase followed by an underscore and 'widget'. The class name in the file must be one word with the first letter and Widget capitalized. This is how it should start:

{% highlight ruby %}
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
class DemotableWidget < Qt::TableWidget
include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS)
      super(target_name, packet_name, item_name, value_type)
    end

end
end
{% endhighlight %}

We're extending the closest widget that Qt offers to what we're trying to achieve. In this case it's pretty obvious but you can get documentation on [all the Qt classes](http://doc.qt.io/qt-4.8/classes.html). In many cases it might be easier to extend an existing [COSMOS widget](https://github.com/BallAerospace/COSMOS/tree/master/lib/cosmos/tools/tlm_viewer/widgets).

Note that our initialize method takes the parent_layout as the first value. All COSMOS widgets make the first parameter the parent_layout so they can be added. The next four paramaters are typically the target_name, packet_name, item_name and value_type. Additional parameters can follow the value_type parameter. The first thing we do in the initialize method is call super which calls the Widget initialize method. If you run this code you should see that the screen displays but doesn't look any different. That's because we haven't actually added our new widget to the parent_layout. Before adding widgets to the layout you typically want to configure them. For our table, we need to set the number of rows and columns. First I grab the telemetry value from the server using the `System.telemetry.value` method defined in [telemetry.rb](https://github.com/BallAerospace/COSMOS/blob/cosmos4/lib/cosmos/packets/telemetry.rb). Since this is an array value I call `length` to determine how many rows to display in the table. I then use the Qt methods `setRowCount` and `setColumnCount` to initialize the table. You can find these methods in the [Qt::TableWidget](http://doc.qt.io/qt-4.8/qtablewidget.html) documentation. Finally I call the addWidget method which is a part of all the [Qt::Layout](http://doc.qt.io/qt-4.8/qlayout.html) classes.

{% highlight ruby %}
def initialize(parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS)
super(target_name, packet_name, item_name, value_type)
value = System.telemetry.value(target_name, packet_name, item_name) # Get the value
@rows = value.length # Store the rows
setRowCount(@rows)
setColumnCount(1)
parent_layout.addWidget(self) if parent_layout
end
{% endhighlight %}

Now if you stop and restart the Telemetry Viewer (so it can re-require the new widget code) it should display an empty table:

![COSMOS Inst Array](/img/2016_08_22_inst_array2.png)

To actually populate it with data we must follow the Cosmos Widget conventions. First of all by including Widget you include all the [Widget](https://github.com/BallAerospace/COSMOS/blob/cosmos4/lib/cosmos/tools/tlm_viewer/widgets/widget.rb) code which creates two key class methods: `layout_manager?` and `takes_value?`. These must be overridden to return true if your widget is either a layout or takes a value respectively. Since our widget will be taking the array data as a value we must override `takes_value?`:

{% highlight ruby %}
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
class DemotableWidget < Qt::TableWidget
include Widget

    def self.takes_value?
      return true
    end

{% endhighlight %}

Typically class methods are defined at the top of the source file and begin with self. You can also type out the class name but this is less robust as changing the class name requires changing the method name. Implementing this class method allows Telemetry Viewer to call the `value=(data)` method with new telemetry data. The value method implementation should look like this:

{% highlight ruby %}
def value=(data)
(0...@rows).each do |row| # Note the extra 'dot' which means up to but not including
setItem(row, 0, Qt::TableWidgetItem.new(data[row].to_s))
end
end
{% endhighlight %}

The data value passed to the method is the same target, packet, and item used in the screen definition. In our value= method we are using our stored instance variable `@rows` to index into the array data and create new [Qt::TableWidgetItem](http://doc.qt.io/qt-4.8/qtablewidgetitem.html) instances to store the data. TableWidgetItems expect Strings to be passed so I call to_s on the data item to ensure it is a String. If you now re-launch Telemetry Viewer you should see the values populated in the table:

![COSMOS Inst Array](/img/2016_08_22_inst_array3.png)

At this point you could be done. But wait! The Array widget below the table fades darker to implement "aging", showing the user the values haven't changed. How do we implement "aging" in our new widget? To start we require the aging_widget and include the AgingWidget module. Then we must call the setup_aging method in our initialize method as well as redefine the process_settings method:

{% highlight ruby %}
require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/aging_widget'

module Cosmos
class DemotableWidget < Qt::TableWidget
include Widget
include AgingWidget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS)
      super(target_name, packet_name, item_name, value_type)
      setup_aging()
      value = System.telemetry.value(target_name, packet_name, item_name) # Get the value
      @rows = value.length # Store the rows
      setRowCount(@rows)
      setColumnCount(1)
      parent_layout.addWidget(self) if parent_layout
    end

    def process_settings
      super
      process_aging_settings
    end

end
end
{% endhighlight %}

Note that we were able to remove the class method `self.takes_value?` because AgingWidget already implements it. This is all required to setup aging but we must still modify the value= method to do the work. First in value= we call super to call the AgingWidget's value= method. This method returns a string representation of the data with the correct foreground color and text character indicating the color, e.g. G=Green, Y=Yellow, R=Red. This is important for values with limits settings but since our array value doesn't have limits I'm going to igore the return value and simply allow the aging routine to age the data. Interally this updates the `@background` instance variable with the current 'aged' background color. I then set the TableWidgetItem's background color to this color before adding it to the table:

{% highlight ruby %}
def value=(data)
super(data)
(0...@rows).each do |row|
item = Qt::TableWidgetItem.new(data[row])
item.setBackgroundColor(@background)
setItem(row, 0, item)
end
end
{% endhighlight %}

The end result is aging:

![COSMOS Inst Array](/img/2016_08_22_inst_array4.png)

Note that if you have a widget that implements aging and limits you'll want to keep the value returned by super and use it in your widget. If you don't want the aging routine to directly use your data value you can pass a string as the second parameter, e.g. super(data, text). This text string will be modified with the color blind settings. Basically that means that whatever the calculated `@foreground` color string is, a corresponding text character is added (R=Red, G=Green, etc) to aid people who can't distinguish colors. See [aging_widget.rb](https://github.com/BallAerospace/COSMOS/blob/cosmos4/lib/cosmos/tools/tlm_viewer/widgets/aging_widget.rb) for more details.

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
