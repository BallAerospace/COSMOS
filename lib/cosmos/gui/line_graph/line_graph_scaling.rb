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

    # Spacer between items
    GRAPH_SPACER = 5

    # Determine the size of the actual graph area
    def determine_graph_size
      metrics = Cosmos.getFontMetrics(@font)

      @graph_left_x = 4 * GRAPH_SPACER
      if @left_y_axis_title
        @graph_left_x += metrics.width('W') + GRAPH_SPACER
      end

      # Determine number of pixels to the right side of graph
      if @show_legend and !@lines.empty? and @legend_position == :right
        legend_x, legend_y, legend_width, legend_height = get_legend_position()
      else
        legend_width = 0
      end
      @graph_right_x = self.width - legend_width - 8 * GRAPH_SPACER
      if @right_y_axis_title
        @graph_right_x -= (metrics.width('W') + GRAPH_SPACER)
      end

      # Determine number of pixels above top of graph
      if @title
        title_metrics = Cosmos.getFontMetrics(@title_font)
        title_height = title_metrics.height
      else
        title_height = 0
      end
      half_y_max_label_height = (metrics.height / 2)
      @graph_top_y = title_height + half_y_max_label_height + GRAPH_SPACER

      # Determine number of pixels below bottom of graph
      if @x_axis_title
        x_axis_title_height = metrics.height + GRAPH_SPACER / 2
      else
        x_axis_title_height = 0
      end
      x_axis_label_height = metrics.height + GRAPH_SPACER

      legend_height = 0
      if @show_legend and !@lines.empty? and @legend_position == :bottom
        text_y = self.height - 1 - (GRAPH_SPACER * 2)
        text_height = metrics.height
        if @lines.axes == :BOTH
          left_text_y  = text_y
          right_text_y = text_y
          @lines.legend.each do |text, color, axis|
            if axis == :LEFT
              left_text_y -= text_height
            else
              right_text_y -= text_height
            end
          end
          if left_text_y < right_text_y
            text_y = left_text_y
          else
            text_y = right_text_y
          end
        else
          @lines.legend.each do |text, color, axis|
            text_y -= text_height
          end
        end
        legend_height = self.height - text_y - GRAPH_SPACER
      end

      @graph_bottom_y = self.height - 1 - (x_axis_title_height + x_axis_label_height + legend_height) - GRAPH_SPACER - GRAPH_SPACER
    end # def determine_graph_size

    # Calculate scaling factors between value and graph coordinates
    def calculate_scaling_factors
      # Determine the x conversion factor between value coordinates and graph coordinates
      if @x_max != @x_min
        @x_scale = (@graph_right_x - @graph_left_x).to_f / (@x_max - @x_min).to_f
      else
        @x_scale = 0.0
      end

      # Determine the y conversion factor between value coordinates and graph coordinates
      if @left_y_max != @left_y_min
        @left_y_scale = (@graph_bottom_y - @graph_top_y).to_f / (@left_y_max - @left_y_min).to_f
      else
        @left_y_scale = 0.0
      end
      if @right_y_max != @right_y_min
        @right_y_scale = (@graph_bottom_y - @graph_top_y).to_f / (@right_y_max - @right_y_min).to_f
      else
        @right_y_scale = 0.0
      end
    end # def calculate_scaling_factors

    # Determine the scale of the graph, either manually or automatically
    def scale_graph
      if @x_auto_scale
        @x_min, @x_max, @x_min_label, @x_max_label = @lines.x_min_max_labels
      end
      scale = @manual_y_grid_line_scale
      if @left_y_auto_scale
        @left_y_min, @left_y_max = auto_scale_y_axis(@lines.left_y_value_range, scale)
      end
      if @right_y_auto_scale
        # scale is nil if there are no left lines to allow for autoscalling
        scale = nil unless @lines.left_y_axis?
        @right_y_min, @right_y_max = auto_scale_y_axis(@lines.right_y_value_range, scale)
      end # def scale_graph
    end

    # Determine the y minimum and maximum values for the given lines and given
    # grid line scale
    #
    # @param lines [Array] Array of lines containing the x and y values
    # @param manual_y_grid_line_scale [Float] Whether there is a manual grid
    #   line scale. The return values will be multiples of this scale if given.
    # @return [Float, Float] The minimum and maximum values
    def auto_scale_y_axis(value_range, manual_y_grid_line_scale)
      y_max = 1
      y_min = -1

      # Ensure we have a valid range of values
      if value_range.size
        y_min = value_range.first
        y_max = value_range.last

        # Add space between values and edges of graph
        diff = y_max - y_min
        if diff == 0.0 and y_min == 0.0
          # Values are all zero so simply add/subtract 1
          y_max = 1
          y_min = -1
        elsif diff == 0.0
          # Values are the same but not zero, so separate them by a multiple of their value
          y_max = y_max + y_max.abs
          y_min = y_min - y_min.abs
        else
          # Give a 5% margin
          y_max += (diff * 0.05)
          y_min -= (diff * 0.05)
        end

        # Determine rough grid line scale
        if manual_y_grid_line_scale
          y_grid_line_scale = manual_y_grid_line_scale
        else
          diff = y_max - y_min
          y_grid_line_scale = calculate_base(diff)
        end

        # Enforce non-zero scale
        y_grid_line_scale = 0.1 if y_grid_line_scale == 0

        # Now move the max and min values so they are multiples of the scale.
        y_min  = y_min - (y_min % y_grid_line_scale)
        y_min -= y_grid_line_scale if y_min == 0
        y_max  = y_max - (y_max % y_grid_line_scale) + y_grid_line_scale
      end

      return y_min, y_max
    end # def auto_scale_y_axis

    # Builds y gridlines for an axis
    def build_y_grid_lines(axis)
      @y_grid_lines = []

      case axis
      when :NONE
        return # Nothing to do if there are no lines
      when :LEFT, :BOTH
        y_max        = @left_y_max
        y_min        = @left_y_min
        y_auto_scale = @left_y_auto_scale
        axis = :LEFT
      when :RIGHT
        y_max        = @right_y_max
        y_min        = @right_y_min
        y_auto_scale = @right_y_auto_scale
      end

      @y_grid_line_scale = determine_grid_line_scale(@manual_y_grid_line_scale, y_min, y_max)
      if @show_y_grid_lines
        states = @lines.unique_y_states(axis)
        if states
          states.each do |state_name, state_value|
            state_value_float = state_value.to_f
            max_length = 0
            if state_value_float <= y_max and state_value_float >= y_min
              # Add gridline for state
              @y_grid_lines << state_value
              max_length = state_name.length if state_name.length > max_length
            end
            if (max_length + 1) > @max_y_characters
              @max_y_characters = max_length + 1
              determine_graph_size()
            end
          end
        else
          calculate_y_grid_lines(y_min, y_max)
        end
      else
        # Just show max and min
        @y_grid_lines << y_max
        @y_grid_lines << y_min
      end
    end

    def calculate_y_grid_lines(y_min, y_max)
      if @manual_y_grid_line_scale
        # With manual grid lines, draw them all regardless of whether it will look nice
        @y_grid_lines << y_min
        grid_value = y_min + @y_grid_line_scale
        if grid_value != y_min
          while grid_value < (y_max - (@y_grid_line_scale / 2.0))
            @y_grid_lines << grid_value
            grid_value += @y_grid_line_scale
          end
        end
        @y_grid_lines << y_max
      else
        # Determine a nice number of gridlines to show not including edges
        metrics = Cosmos.getFontMetrics(@font)
        label_size = metrics.height
        # Calculate the maximum nubmer of grid lines based on the number of
        # labels that can fit. Then add one because the top line can choose
        # not to display its label.
        max_grid_lines = (@graph_bottom_y - @graph_top_y) / label_size + 1
        max_grid_lines = 2 if max_grid_lines < 2

        # Calculate all the possible values between the y minimum and y
        # maximum based on the y scale. These are all possible grid lines.
        possible_grid_lines = []
        possible_grid_lines << y_min
        grid_value = y_min + @y_grid_line_scale
        if grid_value != y_min
          while grid_value < (y_max - (@y_grid_line_scale / 2.0))
            possible_grid_lines << grid_value
            grid_value += @y_grid_line_scale
          end
        end
        possible_grid_lines << y_max

        # Calculate the index through the possible grid lines by dividing
        # the total possible by the maximum that will fit on the graph.
        # Round up the integer math by adding 1.
        num_possible = possible_grid_lines.length
        increment = (num_possible / max_grid_lines) + 1

        @y_grid_lines << y_min
        if increment > 0
          index = increment
          while index < (num_possible - increment)
            @y_grid_lines << possible_grid_lines[index]
            index += increment
          end
          # Add the final increment as long as it doesn't reach the max
          if possible_grid_lines[index] != y_max
            @y_grid_lines << possible_grid_lines[index]
          end
        end
        @y_grid_lines << y_max
      end
    end

    # Builds x gridlines
    def build_x_grid_lines
      @x_grid_lines = []

      @x_grid_line_scale = determine_grid_line_scale(@manual_x_grid_line_scale, @x_min, @x_max)
      if @show_x_grid_lines
        states = @lines.single_line_with_x_states
        if states
          states.each do |state_name, state_value|
            state_value_float = state_value.to_f
            max_length = 0
            if state_value_float <= @x_max and state_value_float >= @x_min
              # Add gridline for state
              @x_grid_lines << [state_value, state_name]
              max_length = state_name.length if state_name.length > max_length
            end
            if (max_length + 1) > @max_x_characters
              @max_x_characters = max_length + 1
              determine_graph_size()
            end
          end
        else
          calculate_x_grid_lines()
        end
      else
        if @x_max_label or @x_min_label
          x_max_length = @x_max_label.to_s.length
          x_min_length = @x_min_label.to_s.length
          if x_max_length > x_min_length
            max_length = x_max_length
          else
            max_length = x_min_length
          end
          if (max_length + 1) > @max_x_characters
            @max_x_characters = max_length + 1
            determine_graph_size()
          end
        end

        # Just show max and min
        @x_grid_lines << [@x_max, @x_max_label]
        @x_grid_lines << [@x_min, @x_min_label]
      end
    end # def build_x_grid_lines

    # Calculate the x grid lines for the graph
    def calculate_x_grid_lines
      if @manual_x_grid_line_scale
        # With manual grid lines, draw them all regardless of whether it will look nice
        @x_grid_lines << [@x_min, nil]
        grid_value = @x_min + @x_grid_line_scale
        if grid_value != @x_min
          while grid_value < (@x_max - (@x_grid_line_scale / 2.0))
            @x_grid_lines << [grid_value, nil]
            grid_value += @x_grid_line_scale
          end
        end
        @x_grid_lines << [@x_max, nil]
      else
        # Determine a nice number of gridlines to show not including edges
        metrics = Cosmos.getFontMetrics(@font)
        label_size = metrics.width("HH:MM:SS:XXX")
        # Calculate the maximum number of grid lines based on the number
        # of labels that can fit. Then add one because the far right line
        # can choose not to display its label.
        max_grid_lines = (@graph_right_x - @graph_left_x) / label_size + 1
        max_grid_lines = 2 if max_grid_lines < 2

        # Calculate all the possible values between the x minimum and x
        # maximum based on the x scale. These are all possible grid lines.
        possible_grid_lines = []
        possible_grid_lines << @x_min
        grid_value = @x_min + @x_grid_line_scale
        if grid_value != @x_min
          while grid_value < (@x_max - (@x_grid_line_scale / 2.0))
            possible_grid_lines << grid_value
            grid_value += @x_grid_line_scale
          end
        end
        possible_grid_lines << @x_max

        # Calculate the index through the possible grid lines by dividing
        # the total possible by the maximum that will fit on the graph.
        # Round up the integer math by adding 1.
        num_possible = possible_grid_lines.length
        increment = (num_possible / max_grid_lines) + 1

        # Store off all the grid lines that will be displayed
        @x_grid_lines << [@x_min, nil] # far left line
        if increment > 0
          index = increment
          while index < (num_possible - increment)
            @x_grid_lines << [possible_grid_lines[index], nil]
            index += increment
          end
          # Add the final increment as long as it doesn't reach the max
          if possible_grid_lines[index] != @x_max
            @x_grid_lines << [possible_grid_lines[index], nil]
          end
        end
        @x_grid_lines << [@x_max, nil] # far right line
      end
    end

    # This function is used to calculate the "base" for a value.  In this case,
    # the base is defined to be the largest power of 10 that can be used to
    # create a scale from 0 to the value with at least 10 values.
    # Ex:  calculate_base(100) = 10
    #      calculate_base(99)  =  1
    #      calculate_base(10)  =  1
    #      calculate_base(9)   =  0.1
    #      calculate_base(1)   =  0.1
    #      calculate_base(0.9) =  0.01
    #      calculate_base(0.1) =  0.01
    #      calculate_base(0)   =  1 # this one is arbitrary but we don't want to return 0
    def calculate_base(value)
      base = value.abs
      operations = 0
      if base >= 1
        while (true)
          base = base / 10
          if base < 1
            break
          end
          operations += 1
        end
      elsif base != 0
        operations = -1
        while (true)
          base = base * 10
          if base >= 1
            break
          end
          operations -= 1
        end
      else
        operations = 1
      end
      return (10**(operations - 1)).to_f
    end # def calculate_base

    # This function converts an x coordinate on the graph to an x value
    def scale_graph_to_value_x(x)
      if (@x_min - @x_max) != 0
        x_scaled = ((x - @graph_left_x).to_f / @x_scale) + @x_min
      else
        x_scaled = 0
      end
      return x_scaled
    end # def scale_graph_to_value_x

    # This function converts an x value to an x coordinate on the graph
    # def scale_value_to_graph_x(x)

    # This function converts a y value to a y coordinate on the graph
    # def scale_value_to_graph_y(y, axis = :LEFT)

    # This function converts a left axis y value to a right axis y value
    def scale_left_to_right_y(left_y)
      slope  = (@right_y_max - @right_y_min) / (@left_y_max - @left_y_min)
      offset = @right_y_max - (@left_y_max * slope)
      return ((left_y * slope) + offset)
    end

    protected

    def determine_grid_line_scale(manual_grid_line_scale, min, max)
      if manual_grid_line_scale
        scale = manual_grid_line_scale
      else
        diff = max - min
        scale = calculate_base(diff)
      end
      return scale
    end

  end # class LineGraph

end # module Cosmos
