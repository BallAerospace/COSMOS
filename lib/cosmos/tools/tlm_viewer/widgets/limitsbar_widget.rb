# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/limits_widget'

module Cosmos
  # Draw a bar which consists of the red low, yellow low, green with potentially
  # a blue operational limits inside it, yellow high, and red high. Then draw a
  # vertical black bar with a little black triangle at the current value location.
  class LimitsbarWidget < LimitsWidget
    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, width = 160, height = 25)
      super(parent_layout, target_name, packet_name, item_name, value_type, width, height)
    end

    def LimitsbarWidget.takes_value?
      return true
    end

    def paint_implementation(dc)
      limits = get_limits()
      return unless limits

      limits, widths = calculate_widths(limits, @bar_width, @min_value, @max_value)

      # Set starting points
      x_pos = @x_pad
      y_pos = @y_pad

      # Draw RED_LOW bar
      dc.addRectColorFill(x_pos, y_pos, widths.red_low, @bar_height, 'red')
      dc.addRectColor(x_pos, y_pos, widths.red_low, @bar_height)
      x_pos += widths.red_low

      # Draw YELLOW_LOW bar
      dc.addRectColorFill(x_pos, y_pos, widths.yellow_low, @bar_height, 'yellow')
      dc.addRectColor(x_pos, y_pos, widths.yellow_low, @bar_height)
      x_pos += widths.yellow_low

      if widths.green_high
        # Draw GREEN_LOW bar
        dc.addRectColorFill(x_pos, y_pos, widths.green_low, @bar_height, 'lime')
        dc.addRectColor(x_pos, y_pos, widths.green_low, @bar_height)
        x_pos += widths.green_low

        # Draw BLUE bar
        dc.addRectColorFill(x_pos, y_pos, widths.blue, @bar_height, 'dodgerblue')
        dc.addRectColor(x_pos, y_pos, widths.blue, @bar_height)
        x_pos += widths.blue

        # Draw GREEN_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, widths.green_high, @bar_height, 'lime')
        dc.addRectColor(x_pos, y_pos, widths.green_high, @bar_height)
        x_pos += widths.green_high
      else
        # Draw GREEN bar
        dc.addRectColorFill(x_pos, y_pos, widths.green, @bar_height, 'lime')
        dc.addRectColor(x_pos, y_pos, widths.green, @bar_height)
        x_pos += widths.green
      end

      # Draw YELLOW_HIGH bar
      dc.addRectColorFill(x_pos, y_pos, widths.yellow_high, @bar_height, 'yellow')
      dc.addRectColor(x_pos, y_pos, widths.yellow_high, @bar_height)
      x_pos += widths.yellow_high

      # Draw RED_HIGH bar
      dc.addRectColorFill(x_pos, y_pos, widths.red_high, @bar_height, 'red')
      dc.addRectColor(x_pos, y_pos, widths.red_high, @bar_height)
      x_pos += widths.red_high

      # Draw line at current value
      red_low = limits[0]
      red_high = limits[3]
      # Start with a diviser of 0.8 assuming we'll draw red limits
      diviser = 0.8
      # If there is a min or max value equal to the min or or max red limit
      # it means we're not drawing red bar and the diviser increases
      diviser += 0.1 if @min_value && limits[0] == @min_value
      diviser += 0.1 if @max_value && limits[3] == @max_value
      @bar_scale = (red_high - red_low) / diviser
      if @min_value && @min_value >= red_low
        @low_value = @min_value
      else
        @low_value = red_low - 0.1 * @bar_scale
      end
      if @max_value && @max_value <= red_high
        @high_value = @max_value
      else
        @high_value = red_high + 0.1 * @bar_scale
      end

      if @value.is_a?(Float) && (@value.infinite? || @value.nan?)
        if @value.infinite? == 1
          @line_pos = @bar_width + @x_pad
        else
          @line_pos = @x_pad
        end
      else
        @line_pos = (@x_pad + (@value - @low_value) / @bar_scale * @bar_width).to_i
        if @line_pos < @x_pad
          @line_pos = @x_pad
        end
        if @line_pos > @x_pad + @bar_width
          @line_pos = @bar_width + @x_pad
        end
      end

      dc.addLineColor(@line_pos, @y_pad - 3, @line_pos, @y_pad + @bar_height + 3)

      # Draw triangle above current value line
      top_triangle = Qt::Polygon.new(3)
      top_triangle.setPoint(0, @line_pos, @y_pad - 1)
      top_triangle.setPoint(1, @line_pos-5, @y_pad - 6)
      top_triangle.setPoint(2, @line_pos+5, @y_pad - 6)
      dc.setBrush(Cosmos::BLACK)
      dc.drawPolygon(top_triangle)
      top_triangle.dispose

      # Additional drawing for subclasses
      additional_drawing(dc)
    end
  end
end
