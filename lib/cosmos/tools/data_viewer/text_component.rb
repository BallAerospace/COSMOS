# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/data_viewer/data_viewer_component'

module Cosmos
  # Displays strings from a telemetry item. To use this in a script
  # you can call inject_tlm("TGT", "PKT", "ITEM": "{red}Error text")
  # The color is in brackets and can be any color recognized by COSMOS.
  class TextComponent < DataViewerComponent
    # @param parent [Qt::Widget] Parent widget
    # @param tab_name [String] Name of the tab which displays this widget
    # @param item_name [String] Name of the item to read from the packet
    def initialize(parent, tab_name, item_name)
      super(parent, tab_name)
      @item_name = item_name
    end

    # Override the update_gui to display the text
    def update_gui
      begin
        loop do
          latest = @processed_queue.pop(true)
          if latest =~ /{.*}/ # Check for a color designator
            color = latest[(latest.index('{') + 1)...latest.index('}')]
            @text.appendText(latest.sub(/{.*}/,''), Cosmos.getColor(color))
          else # add black text
            @text.appendText(latest)
          end
        end
      rescue ThreadError
        # Nothing to do
      end
    end

    # Add the time and the item to the queue
    def process_packet(packet)
      processed_text = ''
      processed_text << "#{packet.received_time.formatted}" if packet.received_time
      processed_text << " #{packet.read(@item_name)}"
      # Ensure that queue does not grow infinitely while paused
      if @processed_queue.length < 1000
        @processed_queue << processed_text
      end
    end
  end
end
