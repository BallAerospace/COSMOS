# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # LineGraph class continued
  class LineGraph < Qt::Widget

    # Builds popups associated with an x value
    def build_popups_from_x_value(x_value)
      # Clear any existing popups
      @popups = []

      if x_value <= @x_max and x_value >= @x_min
        # Determine how near in x value that the cursor must be to a point
        value_delta = ((@x_max - @x_min).to_f / (@graph_right_x - @graph_left_x)) * 3.0 # within 3 pixels

        # Add the popups
        add_popups_for_lines(x_value, value_delta)

        # Make sure popups don't overlap
        adjust_popup_positions()
      end
    end # def build_popups_from_x_value

    # Add popups for the lines on one axis
    def add_popups_for_lines(x_value, value_delta)
      popup_values = @lines.get_left_popup_data(x_value, value_delta, @ordered_x_values, @left_y_min, @left_y_max)
      popup_values.concat(@lines.get_right_popup_data(x_value, value_delta, @ordered_x_values, @right_y_min, @right_y_max))
      popup_values.each do |x, y, x_text, y_text, item, color, axis|
        # The get_xxx_popup_data routine can return an empty array if there are
        # no values for the axis so skip any empty arrays (x is nil)
        next unless x

        # Determine position in graph coordinates
        graph_x = scale_value_to_graph_x(x)
        graph_y = scale_value_to_graph_y(y, axis)

        x_text = convert_x_value_to_text(x_text.to_f, @max_x_characters)
        if @left_button_pressed
          popup_text = "(#{item}) #{x_text}, #{y_text}"
        else
          popup_text = "#{x_text}, #{y_text}"
        end

        # Determine popup's width and height based on width/height of text
        metrics = Qt::FontMetrics.new(@font)
        popup_width = metrics.width(popup_text) + 10
        popup_height = metrics.height + 10

        # Make sure that the popup stays in the graph window on the x axis.
        graph_x_adjusted = popup_width + graph_x
        if graph_x_adjusted > self.width
          graph_x -= popup_width
          graph_x = 0 if graph_x < 0
        end

        # Make sure that the popup stays in the graph window on the y axis.
        graph_y_adjusted = popup_height + graph_y
        if graph_y_adjusted > (self.height - 1)
          graph_y = self.height - 1 - popup_height
        else
          graph_y -= popup_height
        end
        graph_y = 1 if graph_y < 1

        # Add popup
        @popups << [popup_text, graph_x, graph_y, popup_width, popup_height, color]
      end
    end # def add_popups_for_line

    # Algorithm to not overlap popups
    def adjust_popup_positions
      # Sort popups by graph_y
      @popups.sort! {|a,b| a[2] <=> b[2]}

      # Determine if any popups overlap vertically
      overlap = false
      index = 0
      max_index = @popups.length - 1
      @popups.each do |popup_text, graph_x, graph_y, popup_width, popup_height, color|
        break if index == max_index
        if (graph_y + popup_height) > @popups[index + 1][2] # graph_y of next popup
          overlap = true
          break
        end
        index += 1
      end

      # Handle overlap case
      if overlap
        # Determine needed statistics
        combined_height = 0
        @popups.each do |popup_text, graph_x, graph_y, popup_width, popup_height, color|
          combined_height += popup_height + 1
        end

        # Stack popups around center of canvas
        next_graph_y = ((self.height / 2) - (combined_height / 2)).to_i
        @popups.length.times do |popup_index|
          @popups[popup_index][2] = next_graph_y
          next_graph_y += @popups[popup_index][4] + 2
        end
      end
    end # def adjust_popup_positions

  end # class LineGraph
end # module Cosmos

