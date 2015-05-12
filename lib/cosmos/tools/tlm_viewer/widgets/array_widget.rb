# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/aging_widget'

module Cosmos

  class ArrayWidget < Qt::TextEdit
    include Widget
    include AgingWidget

    def initialize(parent_layout, target_name, packet_name, item_name, width = 200, height = 100, format_string = nil, items_per_row = 4, value_type = :CONVERTED)
      super(target_name, packet_name, item_name, value_type)
      setup_aging
      @format_string = ConfigParser.handle_nil(format_string)
      @items_per_row = items_per_row.to_i
      setFixedSize(width.to_i, height.to_i)
      setReadOnly(true)
      setFont(Cosmos.get_default_font)
      parent_layout.addWidget(self) if parent_layout
    end

    def value=(data)
      scroll_pos = self.verticalScrollBar.value
      text = ""
      space = ' '
      new_line = "\n"
      count = 0
      if data.respond_to? :each
        data.each do |value|
          if @format_string
            text << sprintf(@format_string, value) << space
          else
            text << value.to_s << space
          end
          count += 1
          if (count % @items_per_row) == 0
            count = 0
            text << new_line
          end
        end
      else
        text = data.to_s
      end
      self.text = super(data, text)
      self.setColors(@foreground, @background)
      self.verticalScrollBar.value = scroll_pos
    end

    def process_settings
      super
      process_aging_settings
    end

  end

end # module Cosmos
