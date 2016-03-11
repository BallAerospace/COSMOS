# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'ostruct'
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  # This class is a common base class for LimitsbarWidget and
  # LimitscolumnWidget and should not be instantiated
  class LimitsWidget < Qt::Label
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type, width, height)
      super(target_name, packet_name, item_name, value_type)
      @value_type = :CONVERTED if @value_type == :WITH_UNITS
      @width = width.to_i
      @height = height.to_i
      @value = 0
      @x_pad = 6
      @y_pad = 6
      @bar_width = @width - (2 * @x_pad)
      @bar_height = @height - (2 * @y_pad)
      @painter = nil
      setFixedSize(width.to_i, height.to_i)
      parent_layout.addWidget(self) if parent_layout
    end

    def value=(data)
      if String === data
        substring = data[0..2]
        if substring == "Inf".freeze
          data = Float::INFINITY
        elsif substring == "-In".freeze
          data = -Float::INFINITY
        elsif substring == "NaN".freeze
          data = Float::NAN
        end
      end
      @value = data.to_f
      update()
    end

    def paintEvent(event)
      begin
        return if @painter
        @painter = Qt::Painter.new(self)
        # Seems like on initialization sometimes we get some weird bad conditions so check for them
        if @painter.isActive and @painter.paintEngine
          paint_implementation(@painter)
        end
        @painter.dispose
        @painter = nil
      rescue Exception => err
        Cosmos.handle_fatal_exception(err)
      end
    end

    def get_limits
      limits = nil
      limits_values = @item.limits.values
      if limits_values
        limits = limits_values[@limits_set]
        limits = limits_values[:DEFAULT] unless limits
      end
      limits
    end

    def calculate_widths(limits, length)
      red_low = limits[0]
      yellow_low = limits[1]
      yellow_high = limits[2]
      red_high = limits[3]
      green_low = limits[4]
      green_high = limits[5]

      widths = OpenStruct.new
      # Calculate sizes of limits sections
      widths.red_low  = (0.1 * length).round
      widths.red_high = (0.1 * length).round

      inner_value_range = red_high - red_low

      widths.yellow_low  = ((yellow_low - red_low)   / inner_value_range * 0.8 * length).round
      widths.yellow_high = ((red_high - yellow_high) / inner_value_range * 0.8 * length).round

      if green_high
        widths.green_low  = ((green_low - yellow_low)   / inner_value_range * 0.8 * length).round
        widths.green_high = ((yellow_high - green_high) / inner_value_range * 0.8 * length).round
        widths.blue = length - widths.red_low - widths.yellow_low - widths.green_low -
          widths.green_high - widths.yellow_high - widths.red_high
      else
        widths.green = length - widths.red_low - widths.yellow_low -
          widths.yellow_high - widths.red_high
      end
      widths
    end

    protected

    def additional_drawing(dc)
      # Do nothing
    end
  end

end # module Cosmos
