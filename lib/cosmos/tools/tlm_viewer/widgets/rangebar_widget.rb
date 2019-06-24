# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/limitsbar_widget'

module Cosmos
  # Display a bar with a vertical current value indicator which moves based
  # on the value of the given telemetry item
  class RangebarWidget < LimitsbarWidget
    def initialize(parent_layout, target_name, packet_name, item_name, low_value, high_value, value_type = :CONVERTED, width = 160, height = 25)
      super(parent_layout, target_name, packet_name, item_name, value_type, width, height)
      @low_value = low_value.to_s.convert_to_value
      @high_value = high_value.to_s.convert_to_value
    end

    def paint_implementation(dc)
      # Fill the rectangle with white
      dc.addRectColorFill(@x_pad, @y_pad, @width - @x_pad - @x_pad, @height - @y_pad - @y_pad, "white")

      # Draw line at current value
      @bar_scale = @high_value - @low_value

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

      # Draw overall border
      dc.addRectColor(@x_pad, @y_pad, @width - @x_pad - @x_pad, @height - @y_pad - @y_pad)

      #Additional drawing for subclasses
      additional_drawing(dc)
    end
  end
end
