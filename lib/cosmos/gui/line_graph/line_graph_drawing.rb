# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # LineGraph class continued
  class LineGraph < Qt::Widget
    # Pixels for a label tick
    LABEL_TICK_SIZE = 3
    FRAME_OFFSET = 3
    LEFT_X_LABEL_WIDTH_ADJUST = 10

    @@gradient = Qt::LinearGradient.new(Qt::PointF.new(0, 0), Qt::PointF.new(0, 1))
    @@gradient.setColorAt(0, Cosmos.getColor(250, 250, 250))
    @@gradient.setColorAt(0.6, Cosmos.getColor(235, 235, 235))
    @@gradient.setColorAt(1, Cosmos.getColor(220, 220, 220))
    @@gradient.setCoordinateMode(Qt::Gradient::ObjectBoundingMode)

    def draw_graph_into_back_buffer
      # Determine the scale of the graph
      determine_graph_size()
      scale_graph()
      build_x_grid_lines()
      build_y_grid_lines(@lines.axes)
      calculate_y_labels()
      calculate_scaling_factors()

      # Draw overall graph and origin lines
      draw_graph_background(@painter)
      draw_origin_lines(@painter)

      # Draw gridlines and titles
      draw_x_axis_grid_lines(@painter)
      draw_y_axis_grid_lines(@painter)
      draw_horizontal_lines(@painter)
      draw_title(@painter)
      draw_x_axis_title(@painter)
      draw_y_axis_title(@painter, :LEFT)
      draw_y_axis_title(@painter, :RIGHT)

      draw_legend(@painter)

      draw_lines(@painter, :LEFT)
      draw_lines(@painter, :RIGHT)
    end # def draw_graph_into_buffer

    # Draws the graph to the screen
    def draw_graph_to_screen
      draw_frame(@painter)

      # Draw cursor line and popups if present
      draw_cursor_line_and_popups(@painter) if @show_cursor_and_popups

      # Draw error icon if present
      draw_error_icon(@painter)
    end # def draw_graph_to_screen

    # Draws the colored rectangle for the graph
    def draw_graph_background(dc)
      dc.addRectColorFill(@graph_left_x, @graph_top_y, @graph_right_x - @graph_left_x, @graph_bottom_y - @graph_top_y, @label_and_border_color, @@gradient)
    end

    # Draws origin lines if they fall on the graph
    def draw_origin_lines(dc)
      if (@left_y_max > 0) and (@left_y_min < 0) and @lines.axes == :LEFT
        y1 = scale_value_to_graph_y(0.0, :LEFT)
        dc.addLineColor(@graph_left_x - 3, y1, @graph_right_x, y1)
      end
      if (@right_y_max > 0) and (@right_y_min < 0) and @lines.axes == :RIGHT
        y1 = scale_value_to_graph_y(0.0, :RIGHT)
        dc.addLineColor(@graph_left_x, y1, @graph_right_x + 3, y1)
      end
      if (@x_max > 0) and (@x_min < 0)
        x1 = scale_value_to_graph_x(0.0)
        dc.addLineColor(x1, @graph_bottom_y + 3, x1, @graph_top_y)
      end
    end # def draw_origin_lines

    # Draws the gridlines for a y-axis
    def draw_y_axis_grid_lines(dc)
      grid_lines = []
      @y_grid_lines.each_with_index do |value, index|
        # Don't draw gridlines that are too close to 0
        if ((value > (@y_grid_line_scale / 2.0)) || (value < (@y_grid_line_scale / -2.0)))
          grid_lines << draw_y_label(dc, value, index)
        else
          grid_lines << draw_y_label(dc, 0, index)
        end
      end
      # Now draw all the grid lines so we can use a single Pen for all
      grid_lines.each do |y|
        dc.addLineColor(@graph_left_x, y, @graph_right_x, y, Cosmos::DASHLINE_PEN)
      end
    end # def draw_y_axis_grid_lines

    # Calcuate the Y axis labels as well as their width and adjust the size of
    # the graph accordingly
    def calculate_y_labels
      metrics = Cosmos.getFontMetrics(@font)
      left_widths  = [metrics.width("-1.0")]
      right_widths = [0]
      @left_text = []
      @right_text = []

      @y_grid_lines.each do |value|
        value = 0 unless ((value > (@y_grid_line_scale / 2.0)) || (value < (@y_grid_line_scale / -2.0)))
        # Get text for label(s)
        case @lines.axes
        when :BOTH
          @left_text  << convert_y_value_to_text(value, @max_y_characters, :LEFT)
          left_widths << metrics.width(@left_text[-1])
          right_value = scale_left_to_right_y(value)
          @right_text  << convert_y_value_to_text(right_value, @max_y_characters, :RIGHT)
          right_widths << metrics.width(@right_text[-1])
        when :LEFT
          @left_text  << convert_y_value_to_text(value, @max_y_characters, :LEFT)
          left_widths << metrics.width(@left_text[-1])
        when :RIGHT
          @right_text << convert_y_value_to_text(value, @max_y_characters, :RIGHT)
          right_widths << metrics.width(@right_text[-1])
        end
      end

      # Also include half of width of first x label into left widths.
      value, label = @x_grid_lines[0]
      if label
        text = label.to_s
      else
        text = convert_x_value_to_text(value, @max_x_characters)
      end
      left_widths << ((metrics.width(text) / 2) - LEFT_X_LABEL_WIDTH_ADJUST)

      @graph_left_x += left_widths.max
      @graph_right_x -= (right_widths.max + GRAPH_SPACER)
    end

    # This function is used to draw the y labels.
    def draw_y_label(dc, value, index)
      left_value = value
      right_value = value
      left_text = @left_text[index]
      right_text = @right_text[index]

      y = nil
      if left_text
        metrics = Cosmos.getFontMetrics(@font)
        text_width = metrics.width(left_text)
        x = @graph_left_x
        y = scale_value_to_graph_y(left_value, :LEFT)
        if (y < @graph_top_y)
          y = @graph_top_y
        elsif (y > @graph_bottom_y)
          y = @graph_bottom_y
        end
        dc.addLineColor(x - LABEL_TICK_SIZE + 1, y, x, y)

        # Only display the label if we have room. This only affects the top
        # side of the graph since that's where new grid lines appear.
        if (y == @graph_top_y) || ((y - @font_size) > @graph_top_y)
          dc.addSimpleTextAt(left_text,
                             x - text_width - GRAPH_SPACER,
                             y + (@font_size / 2))
        end
      end

      if right_text
        x = @graph_right_x
        y = scale_value_to_graph_y(right_value, :RIGHT) unless y
        if (y < @graph_top_y)
          y = @graph_top_y
        elsif (y > @graph_bottom_y)
          y = @graph_bottom_y
        end
        dc.addLineColor(x, y, x + LABEL_TICK_SIZE, y)

        # Only display the label if we have room. This only affects the top
        # side of the graph since that's where new grid lines appear.
        if (y == @graph_top_y) || ((y - @font_size) > @graph_top_y)
          dc.addSimpleTextAt(right_text,
                             x + 2 * GRAPH_SPACER,
                             y + (@font_size / 2))
        end
      end
      return y
    end

    # Draws the gridlines for the x-axis
    def draw_x_axis_grid_lines(dc)
      grid_lines = []
      @x_grid_lines.each do |value, label|
        # If the line has states or is far enough away from the origin
        if @lines.x_states || ((value > (@x_grid_line_scale / 2.0)) || (value < (@x_grid_line_scale / -2.0)))
          grid_lines << draw_x_label(dc, value, label)
        else
          grid_lines << draw_x_label(dc, 0, nil)
        end
      end
      # Now draw all the grid lines so we can use a single Pen for all
      grid_lines.each do |x1, y1, x2, y2|
        dc.addLineColor(x1, y1, x2, y2, Cosmos::DASHLINE_PEN)
      end
    end # def draw_x_axis_grid_lines

    # This function is used to draw the x labels and returns the line
    # positions.
    def draw_x_label(dc, value, label)
      if label
        text = label.to_s
      else
        text = convert_x_value_to_text(value, @max_x_characters)
      end
      metrics = Cosmos.getFontMetrics(@font)
      text_width  = metrics.width(text)
      text_height = metrics.height
      x1 = scale_value_to_graph_x(value)
      y1 = @graph_bottom_y + LABEL_TICK_SIZE
      if (x1 < @graph_left_x)
        x1 = @graph_left_x
      end
      if (x1 > @graph_right_x)
        x1 = @graph_right_x
      end
      y2 = @graph_top_y
      x2 = x1

      # Only display the label if we have room. This really only affects the
      # right side of the graph since that's where new grid lines appear. The
      # 1.25 is because we shift the far right label over a bit to eliminate
      # white space on the right side of the graph.
      if (x1 == @graph_right_x) || (x1 < (@graph_right_x - (1.25 * text_width)))
        # Shift the far right label left a bit to eliminate white space
        text_x = x1 - text_width / 4 if x1 == @graph_right_x
        text_x = x1 - text_width / 2 # center the text
        dc.addSimpleTextAt(text, text_x, @graph_bottom_y + text_height + GRAPH_SPACER)
      end
      [x1, y1, x2, y2]
    end # def draw_x_label_and_grid_line

    # Converts a x value into text with a max number of characters
    def convert_x_value_to_text(value, max_characters, full_date = false)
      if !@show_popup_x_y and @unix_epoch_x_values
        if (value > 1 and value < 2147483647)
          time = Time.at(value.to_f)
          time = time.utc if @utc_time
          if full_date
            text = time.formatted # full date with day, month, year
          else
            text = time.formatted(false) # just hour, minutes, seconds
          end
        else
          text = value.to_s
        end
      else
        text = value.to_s
      end
      truncate_to_max(text, max_characters, value)
    end

    # Converts a y value into text with a max number of characters
    def convert_y_value_to_text(value, max_characters, axis)
      states = @lines.unique_y_states(axis)
      if states
        text = states.key(value)
      else
        text = truncate_to_max(value.to_s, max_characters, value)
      end
      return text
    end

    # Draws any extra horizontal lines onto the graph
    def draw_horizontal_lines(dc)
      @horizontal_lines.each do |y_value, color, axis|
        y = scale_value_to_graph_y(y_value, axis)
        if (y > @graph_top_y) and (y < @graph_bottom_y)
          dc.addLineColor(@graph_left_x, y, @graph_right_x, y, color)
        end
      end
    end

    # Draw the overall graph title above the graph
    def draw_title(dc)
      if @title
        metrics = Cosmos.getFontMetrics(@title_font)
        dc.setFont(@title_font)
        dc.addSimpleTextAt(@title, (self.width / 2) - (metrics.width(@title) / 2), metrics.height)
        dc.setFont(@font)
      end
    end

    # Draws the x axis title below the graph
    def draw_x_axis_title(dc)
      if @x_axis_title
        metrics = Cosmos.getFontMetrics(@font)
        text_width  = metrics.width(@x_axis_title)
        text_height = metrics.height
        dc.addSimpleTextAt(@x_axis_title,
          (((@graph_right_x - @graph_left_x) / 2) + @graph_left_x) - (text_width / 2),
          @graph_bottom_y + (2 * text_height) + GRAPH_SPACER)
      end
    end

    # Draws titles to the left and right of the Y axis
    def draw_y_axis_title(dc, axis)
      metrics = Cosmos.getFontMetrics(@font)
      if axis == :LEFT
        y_axis_title = @left_y_axis_title
        graph_x = GRAPH_SPACER
      else
        y_axis_title = @right_y_axis_title
        graph_x = self.width - metrics.width('W') - GRAPH_SPACER - FRAME_OFFSET
      end

      if y_axis_title
        text_height = metrics.height
        total_height = text_height * y_axis_title.length
        start_height = (height - total_height) / 2
        max_width = metrics.width('W')
        y_axis_title.length.times do |index|
          character = y_axis_title[index..index]
          cur_width = metrics.width(character)
          dc.addSimpleTextAt(character, graph_x + ((max_width - cur_width) / 2), start_height + text_height * index)
        end
      end
    end

    # Draws the legend on the bottom of the graph
    def draw_legend(dc)
      return if !@show_legend || @lines.empty?

      text_x, text_y, legend_width, legend_height = get_legend_position()
      if @lines.axes == :BOTH
        draw_legend_text(dc, :LEFT, text_x, text_y, legend_height)
        draw_legend_text(dc, :RIGHT, text_x + (legend_width / 2), text_y, legend_height)
      else
        draw_legend_text(dc, false, text_x, text_y, legend_height)
      end
    end

    # Calculate the legend x, y, width and height
    def get_legend_position
      metrics = Cosmos.getFontMetrics(@font)
      legend_width = 0
      @lines.legend.each do |legend_text, color, axis|
        text_width   = metrics.width(legend_text)
        legend_width = text_width if text_width > legend_width
      end
      legend_width += (GRAPH_SPACER * 2)
      legend_width *= 2 if @lines.axes == :BOTH
      legend_graph_x = (self.width - legend_width) / 2

      text_x = legend_graph_x + GRAPH_SPACER
      text_y = self.height - metrics.height
      return [text_x, text_y, legend_width, metrics.height]
    end

    def draw_legend_text(dc, specific_axis, text_x, text_y, line_height)
      @lines.legend.reverse_each do |legend_text, color, axis|
        if !specific_axis || specific_axis == axis
          dc.addSimpleTextAt(legend_text, text_x, text_y, color)
          text_y -= line_height
        end
      end
    end

    # Draws all lines for the given axis
    # def draw_lines(dc, axis)

    # Draws a line between two points that is clipped to fit the visible graph if necessary
    # def draw_line(dc, x1, y1, x2, y2, show_line, point_size, axis, color)

    # Draws the cursor line and popups if needed - called from drawForeground
    def draw_cursor_line_and_popups(dc)
      if @mouse_in_window == true
        # Draw the cursor line at mouse position
        x = scale_graph_to_value_x(mapFromGlobal(cursor.pos).x)
        draw_cursor_line_and_popups_at_x(dc, x)

        # Call callback when the mouse caused the cursor to draw
        saved_callback = @draw_cursor_line_callback
        @draw_cursor_line_callback = nil
        saved_callback.call(self, x, @left_button_pressed) if saved_callback
        @draw_cursor_line_callback = saved_callback
      elsif @cursor_line_x
        # Draw the cursor line at given position
        draw_cursor_line_and_popups_at_x(dc, @cursor_line_x)
      end
    end

    # Draws the cursor line at a given position and builds the popups
    def draw_cursor_line_and_popups_at_x(dc, x)
      # Draw cursor line
      if @lines.left_y_axis? and x <= @x_max and x >= @x_min
        draw_line(dc, x, @left_y_min, x, @left_y_max, true, 0, :LEFT, @back_color)
      elsif @lines.right_y_axis? and x <= @x_max and x >= @x_min
        draw_line(dc, x, @right_y_min, x, @right_y_max, true, 0, :RIGHT, @back_color)
      end

      # Build and draw popups
      build_popups_from_x_value(x)
      draw_popups(dc)
    end

    # Draws popup boxes if any
    def draw_popups(dc)
      unless @popups.empty?
        # Draw each popup
        @popups.each do |popup_text, popup_x, popup_y, popup_width, popup_height, popup_color|
          # Draw overall rectangle
          dc.addRectColorFill(popup_x, popup_y, popup_width, popup_height, @back_color)

          # Draw border around rectangle in line color
          dc.addRectColor(popup_x, popup_y, popup_width, popup_height, popup_color)

          # Draw popup text
          dc.addSimpleTextAt(popup_text, popup_x + 5, popup_y + popup_height - 7, @label_and_border_color)
        end # popups.each
      end # unless popups.empty?
    end

    # Draws the overall frame around the graph, legend, labels, etc
    def draw_frame(dc)
      dc.addRectColor(0,0,self.width-1,self.height-1, @frame_color)
    end

    # Draws an icon that indicates an error has occurred
    def draw_error_icon(dc)
      if @error
        dc.addEllipseColor(@graph_right_x - 60, 20, 40, 40, 'red')
        dc.addRectColorFill(@graph_right_x - 42, 25, 4, 20, 'red')
        dc.addRectColorFill(@graph_right_x - 42, 50, 4, 4, 'red')
      end
    end

    # Handles window resizes and enforces a minimum size
    def update_graph_size
      unless @in_update_graph_size
        @in_update_graph_size = true

        # Get new width and height
        new_width  = self.width
        new_height = self.height

        # Enforce a minimum width and height
        if (new_width < @minimum_width)
          new_width = @minimum_width
        end
        if (new_height < @minimum_height)
          new_height = @minimum_height
        end

        # Make sure everything is the correct size
        self.resize(new_width, new_height)

        @in_update_graph_size = false
      end
    end # def update_graph_size

    protected

    def truncate_to_max(text, max_characters, value)
      if text.length > max_characters
        text = sprintf("%0.#{max_characters}g", value.to_f)
        if text.length > max_characters
          text = sprintf("%0.#{max_characters - 5}g", value.to_f)
        end
      end
      text
    end

  end # end class LineGraph

end # module Cosmos
