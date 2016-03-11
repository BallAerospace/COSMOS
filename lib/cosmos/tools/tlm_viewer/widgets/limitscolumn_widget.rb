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

  class LimitscolumnWidget < LimitsWidget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, width = 30, height = 100)
      super(parent_layout, target_name, packet_name, item_name, value_type, width, height)
    end

    def LimitscolumnWidget.takes_value?
      return true
    end

    def paint_implementation(dc)
      limits = get_limits()
      return unless limits

      widths = calculate_widths(limits, @bar_height)

      # Set starting points
      x_pos = @x_pad
      y_pos = @y_pad

      # Draw RED_LOW bar
      dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.red_low, 'red')
      dc.addRectColor(x_pos, y_pos, @bar_width, widths.red_low)
      y_pos += widths.red_low

      # Draw YELLOW_LOW bar
      dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.yellow_low, 'yellow')
      dc.addRectColor(x_pos, y_pos, @bar_width, widths.yellow_low)
      y_pos += widths.yellow_low

      if widths.green_high
        # Draw GREEN_LOW bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.green_low, 'lime')
        dc.addRectColor(x_pos, y_pos, @bar_width, widths.green_low)
        y_pos += widths.green_low

        # Draw BLUE bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.blue, 'dodgerblue')
        dc.addRectColor(x_pos, y_pos, @bar_width, widths.blue)
        y_pos += widths.blue

        # Draw GREEN_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.green_high, 'lime')
        dc.addRectColor(x_pos, y_pos, @bar_width, widths.green_high)
        y_pos += widths.green_high
      else
        # Draw GREEN bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.green, 'lime')
        dc.addRectColor(x_pos, y_pos, @bar_width, widths.green)
        y_pos += widths.green
      end

      # Draw YELLOW_HIGH bar
      dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.yellow_high, 'yellow')
      dc.addRectColor(x_pos, y_pos, @bar_width, widths.yellow_high)
      y_pos += widths.yellow_high

      # Draw RED_HIGH bar
      dc.addRectColorFill(x_pos, y_pos, @bar_width, widths.red_high, 'red')
      dc.addRectColor(x_pos, y_pos, @bar_width, widths.red_high)
      y_pos += widths.red_high

      # Draw line at current value
      red_low = limits[0]
      red_high = limits[3]
      @bar_scale = (red_high - red_low) / 0.8
      @low_value = red_low - 0.1 * @bar_scale
      @high_value = red_high + 0.1 * @bar_scale

      if @value.is_a?(Float) && (@value.infinite? || @value.nan?)
        if @value.infinite? == 1
          @line_pos = @bar_width + @y_pad
        else
          @line_pos = @y_pad
        end
      else
        @line_pos = @height - (@y_pad + (@value - @low_value) / @bar_scale * @bar_height).to_i
        if @line_pos < @y_pad
          @line_pos = @y_pad
        end
        if @line_pos > @y_pad + @bar_height
          @line_pos = @bar_height + @y_pad
        end
      end

      dc.addLineColor(@x_pad - 3, @line_pos, @x_pad + @bar_width + 3, @line_pos)

      # Draw triangle next to current value line
      top_triangle = Qt::Polygon.new(3)
      top_triangle.setPoint(0, @x_pad + @bar_width, @line_pos)
      top_triangle.setPoint(1, @x_pad + @bar_width + 5, @line_pos + 5)
      top_triangle.setPoint(2, @x_pad + @bar_width + 5, @line_pos - 5)
      dc.setBrush(Cosmos::BLACK)
      dc.drawPolygon(top_triangle)
      top_triangle.dispose

      # Additional drawing for subclasses
      additional_drawing(dc)
    end
  end

end # module Cosmos
