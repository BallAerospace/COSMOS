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
      raise "Invalid value_type #{@value_type} for LimitsWidget" if @value_type == :RAW
      @width = width.to_i
      @height = height.to_i
      @value = 0
      @x_pad = 6
      @y_pad = 6
      @bar_width = @width - (2 * @x_pad)
      @bar_height = @height - (2 * @y_pad)
      @painter = nil
      @min_value = nil # no minimum
      @max_value = nil # no maximum
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

    def process_settings
      super
      @settings.each do |setting_name, setting_values|
        case setting_name
        when 'MIN_VALUE'
          @min_value = setting_values[0].to_f
        when 'MAX_VALUE'
          @max_value = setting_values[0].to_f
        end
      end
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

    def calculate_widths(limits, length, min_value = nil, max_value = nil)
      red_low = limits[0]
      yellow_low = limits[1]
      yellow_high = limits[2]
      red_high = limits[3]
      green_low = limits[4]
      green_high = limits[5]

      widths = OpenStruct.new
      # Calculate sizes of limits sections
      # By default the red low and red high sections are each
      # 10% of the total bar length. After the value goes beyond
      # a certain point it just rails on the red section.
      widths.red_low  = (0.1 * length).round
      widths.red_high = (0.1 * length).round

      if min_value
        # If the red low is less than the min value we don't display the red low box
        if red_low <= min_value
          red_low = min_value
          widths.red_low = 0
        end
        # Determine if any other limits values need to change
        yellow_low = min_value if yellow_low <= min_value
        green_low = min_value if green_low && green_low <= min_value
        green_high = min_value if green_high && green_high <= min_value
        yellow_high = min_value if yellow_high <= min_value
        red_high = min_value if red_high <= min_value
      end
      if max_value
        # If the red high is greater than the max value we don't display the red high box
        if red_high >= max_value
          red_high = max_value
          widths.red_high = 0
        end
        # Determine if any other limits values need to change
        yellow_high = max_value if yellow_high >= max_value
        green_high = max_value if green_high && green_high >= max_value
        green_low = max_value if green_low && green_low >= max_value
        yellow_low = max_value if yellow_low >= max_value
        red_low = max_value if red_low >= max_value
      end

      # If red == yellow it means there is no red width
      widths.red_low = 0 if red_low == yellow_low
      widths.red_high = 0 if red_high == yellow_high
      # Start with a scale of 0.8 in case we display the red
      scale = 0.8
      # Move the scale up if we're not displaying red
      scale += 0.1 if widths.red_low == 0
      scale += 0.1 if widths.red_high == 0

      inner_value_range = red_high - red_low
      widths.yellow_low  = ((yellow_low - red_low)   / inner_value_range * scale * length).round
      widths.yellow_high = ((red_high - yellow_high) / inner_value_range * scale * length).round

      if green_high
        widths.green_low  = ((green_low - yellow_low)   / inner_value_range * scale * length).round
        widths.green_high = ((yellow_high - green_high) / inner_value_range * scale * length).round
        widths.blue = length - widths.red_low - widths.yellow_low - widths.green_low -
          widths.green_high - widths.yellow_high - widths.red_high
      else
        widths.green = length - widths.red_low - widths.yellow_low -
          widths.yellow_high - widths.red_high
      end
      return [red_low, yellow_low, yellow_high, red_high, green_low, green_high], widths
    end

    protected

    def additional_drawing(dc)
      # Do nothing
    end
  end
end
