# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  class LimitscolumnWidget < Qt::Label
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, width = 30, height = 100)
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

    def LimitscolumnWidget.takes_value?
      return true
    end

    def value=(data)
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

    def paint_implementation(dc)
      draw_bar = true

      limits_values = @item.limits.values
      if limits_values
        limits = limits_values[@limits_set]
        limits = limits_values[:DEFAULT] unless limits
        if limits
          red_low = limits[0]
          yellow_low = limits[1]
          yellow_high = limits[2]
          red_high = limits[3]
          green_low = limits[4]
          green_high = limits[5]
        else
          draw_bar = false
        end
      else
        draw_bar = false
      end

      if draw_bar
        # Calculate sizes of limits sections
        red_low_height  = (0.1 * @bar_height).round
        red_high_height = (0.1 * @bar_height).round

        inner_value_range = red_high - red_low

        yellow_low_height  = ((yellow_low - red_low)   / inner_value_range * 0.8 * @bar_height).round
        yellow_high_height = ((red_high - yellow_high) / inner_value_range * 0.8 * @bar_height).round

        if green_high
          green_low_height  = ((green_low - yellow_low)   / inner_value_range * 0.8 * @bar_height).round
          green_high_height = ((yellow_high - green_high) / inner_value_range * 0.8 * @bar_height).round
          blue_height = @bar_height - red_low_height - yellow_low_height - green_low_height - green_high_height - yellow_high_height - red_high_height
        else
          green_height = @bar_height - red_low_height - yellow_low_height - yellow_high_height - red_high_height
        end

        # Set starting points
        x_pos = @x_pad
        y_pos = @y_pad

        # Draw RED_LOW bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, red_low_height, 'red')
        dc.addRectColor(x_pos, y_pos, @bar_width, red_low_height)
        y_pos += red_low_height

        # Draw YELLOW_LOW bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, yellow_low_height, 'yellow')
        dc.addRectColor(x_pos, y_pos, @bar_width, yellow_low_height)
        y_pos += yellow_low_height

        if green_high
          # Draw GREEN_LOW bar
          dc.addRectColorFill(x_pos, y_pos, @bar_width, green_low_height, 'lime')
          dc.addRectColor(x_pos, y_pos, @bar_width, green_low_height)
          y_pos += green_low_height

          # Draw BLUE bar
          dc.addRectColorFill(x_pos, y_pos, @bar_width, blue_height, 'dodgerblue')
          dc.addRectColor(x_pos, y_pos, @bar_width, blue_height)
          y_pos += blue_height

          # Draw GREEN_HIGH bar
          dc.addRectColorFill(x_pos, y_pos, @bar_width, green_high_height, 'lime')
          dc.addRectColor(x_pos, y_pos, @bar_width, green_high_height)
          y_pos += green_high_height
        else
          # Draw GREEN bar
          dc.addRectColorFill(x_pos, y_pos, @bar_width, green_height, 'lime')
          dc.addRectColor(x_pos, y_pos, @bar_width, green_height)
          y_pos += green_height
        end

        # Draw YELLOW_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, yellow_high_height, 'yellow')
        dc.addRectColor(x_pos, y_pos, @bar_width, yellow_high_height)
        y_pos += yellow_high_height

        # Draw RED_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, @bar_width, red_high_height, 'red')
        dc.addRectColor(x_pos, y_pos, @bar_width, red_high_height)
        y_pos += red_high_height

        # Draw line at current value
        @bar_scale = (red_high - red_low) / 0.8
        @low_value = red_low - 0.1 * @bar_scale
        @high_value = red_high + 0.1 * @bar_scale

        @line_pos = @height - (@y_pad + (@value - @low_value) / @bar_scale * @bar_height).to_i
        if @line_pos < @y_pad
          @line_pos = @y_pad
        end
        if @line_pos > @y_pad + @bar_height
          @line_pos = @bar_height + @y_pad
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
      end # if draw_bar == true
    end

    protected

    def additional_drawing(dc)
      # Do nothing
    end
  end

end # module Cosmos
