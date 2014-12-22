# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  class LimitsbarWidget < Qt::Label
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, width = 160, height = 25)
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

    def LimitsbarWidget.takes_value?
      return true
    end

    def value= (data)
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
        red_low_width  = (0.1 * @bar_width).round
        red_high_width = (0.1 * @bar_width).round

        inner_value_range = red_high - red_low

        yellow_low_width  = ((yellow_low - red_low)   / inner_value_range * 0.8 * @bar_width).round
        yellow_high_width = ((red_high - yellow_high) / inner_value_range * 0.8 * @bar_width).round

        if green_high
          green_low_width  = ((green_low - yellow_low)   / inner_value_range * 0.8 * @bar_width).round
          green_high_width = ((yellow_high - green_high) / inner_value_range * 0.8 * @bar_width).round
          blue_width = @bar_width - red_low_width - yellow_low_width - green_low_width - green_high_width - yellow_high_width - red_high_width
        else
          green_width = @bar_width - red_low_width - yellow_low_width - yellow_high_width - red_high_width
        end

        # Set starting points
        x_pos = @x_pad
        y_pos = @y_pad

        # Draw RED_LOW bar
        dc.addRectColorFill(x_pos, y_pos, red_low_width, @bar_height, 'red')
        dc.addRectColor(x_pos, y_pos, red_low_width, @bar_height)
        x_pos += red_low_width

        # Draw YELLOW_LOW bar
        dc.addRectColorFill(x_pos, y_pos, yellow_low_width, @bar_height, 'yellow')
        dc.addRectColor(x_pos, y_pos, yellow_low_width, @bar_height)
        x_pos += yellow_low_width

        if green_high
          # Draw GREEN_LOW bar
          dc.addRectColorFill(x_pos, y_pos, green_low_width, @bar_height, 'lime')
          dc.addRectColor(x_pos, y_pos, green_low_width, @bar_height)
          x_pos += green_low_width

          # Draw BLUE bar
          dc.addRectColorFill(x_pos, y_pos, blue_width, @bar_height, 'dodgerblue')
          dc.addRectColor(x_pos, y_pos, blue_width, @bar_height)
          x_pos += blue_width

          # Draw GREEN_HIGH bar
          dc.addRectColorFill(x_pos, y_pos, green_high_width, @bar_height, 'lime')
          dc.addRectColor(x_pos, y_pos, green_high_width, @bar_height)
          x_pos += green_high_width
        else
          # Draw GREEN bar
          dc.addRectColorFill(x_pos, y_pos, green_width, @bar_height, 'lime')
          dc.addRectColor(x_pos, y_pos, green_width, @bar_height)
          x_pos += green_width
        end

        # Draw YELLOW_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, yellow_high_width, @bar_height, 'yellow')
        dc.addRectColor(x_pos, y_pos, yellow_high_width, @bar_height)
        x_pos += yellow_high_width

        # Draw RED_HIGH bar
        dc.addRectColorFill(x_pos, y_pos, red_high_width, @bar_height, 'red')
        dc.addRectColor(x_pos, y_pos, red_high_width, @bar_height)
        x_pos += red_high_width

        # Draw line at current value
        @bar_scale = (red_high - red_low) / 0.8
        @low_value = red_low - 0.1 * @bar_scale
        @high_value = red_high + 0.1 * @bar_scale

        @line_pos = (@x_pad + (@value - @low_value) / @bar_scale * @bar_width).to_i
        if @line_pos < @x_pad
          @line_pos = @x_pad
        end
        if @line_pos > @x_pad + @bar_width
          @line_pos = @bar_width + @x_pad
        end

        dc.addLineColor(@line_pos, @y_pad - 3, @line_pos, @y_pad + @bar_height + 3)

        # Draw triangle above current value line
        top_triangle = Qt::Polygon.new(3)
        top_triangle.setPoint(0, @line_pos, @y_pad - 1)
        top_triangle.setPoint(1, @line_pos-5, @y_pad - 6)
        top_triangle.setPoint(2, @line_pos+5, @y_pad - 6)
        dc.setBrush(Cosmos.getBrush(Cosmos::BLACK))
        dc.drawPolygon(top_triangle)
        top_triangle.dispose

        #Additional drawing for subclasses
        additional_drawing(dc)
      end # if draw_bar == true
    end

    protected

    def additional_drawing (dc)
      # Do nothing
    end
  end

end # module Cosmos
