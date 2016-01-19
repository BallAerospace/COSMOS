# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class Lines
    def initialize
      @lines = []
    end

    # Clears all line data
    def clear
      @lines = []
    end

    # Returns which axes the lines belong to
    #
    # @return [Symbol] :NONE, :LEFT, :RIGHT, or :BOTH
    def axes
      return :NONE if @lines.empty?
      return :LEFT if @lines.select {|line| line[7] == :RIGHT}.empty?
      return :RIGHT if @lines.select {|line| line[7] == :LEFT}.empty?
      return :BOTH
    end

    # @return [Array] Information needed to create the legend including
    #   the item name, axis, and color
    def legend
      @lines.collect {|line| [line[8], line[6], line[7]] }
    end

    # @return [Boolean] Whether any lines are present
    def empty?
      @lines.empty?
    end

    # @return [Integer] Number of lines that are present
    def num_lines
      return @lines.length
    end

    # @return [Boolean] true if there are lines on the left y axis
    def left_y_axis?
      !left().empty?
    end
    # @return [Boolean] true if there are lines on the right y axis
    def right_y_axis?
      !right().empty?
    end

    # Returns the x line states
    #
    # @return [Hash|nil] Line states or nil if none found
    def x_states
      @lines.collect {|line| line[4] }.compact.uniq[0]
    end

    # @return [Array] Popup details for the left Y axis consisting of the
    #   x value, y value, x text, y text, item name, color, and axis
    def get_left_popup_data(x_value, value_delta, ordered_x_values, min, max)
      get_popup_data(left(), x_value, value_delta, ordered_x_values, min, max)
    end
    # @return [Array] Popup details for the right Y axis consisting of the
    #   x value, y value, x text, y text, item name, color, and axis
    def get_right_popup_data(x_value, value_delta, ordered_x_values, min, max)
      get_popup_data(right(), x_value, value_delta, ordered_x_values, min, max)
    end

    private # Protect this implementation detail called by the above methods

    def get_popup_data(lines, x_value, value_delta, ordered_x_values, min, max)
      # Find the data points nearest to the given x value
      result = []
      lines.each do |x_values, y_values, x_labels, y_labels, x_states, y_states, color, axis, item|
        index = x_values.nearest_index(x_value, ordered_x_values)
        if (x_values[index] - x_value).abs < value_delta
          if y_values[index] >= min and y_values[index] <= max
            x_text = get_display_text(x_values, x_states, x_labels, index)
            y_text = get_display_text(y_values, y_states, y_labels, index)
            result << [x_values[index], y_values[index], x_text, y_text, item, color, axis]
          end
        end
      end
      return result
    end

    public

    # @return [Range] The range of left Y axis values
    def left_y_value_range
      y_value_range(left())
    end
    # @return [Range] The range of right Y axis values
    def right_y_value_range
      y_value_range(right())
    end

    private # Protect this implementation detail called by the above methods

    def y_value_range(lines)
      mins = []
      maxs = []
      lines.each do |line|
        mins << line[1].min
        maxs << line[1].max
      end
      (mins.min...maxs.max)
    end

    public

    # Returns the x axis minimum and maximum values along with their labels (if
    # there are any labels).
    #
    # @return [Array<Numeric, Numeric, String, String>]
    def x_min_max_labels
      x_max = 1
      x_min = -1
      x_max_label = nil
      x_min_label = nil

      unless @lines.empty?
        # Use maximum and minimum values for x_max and x_min
        line_max_values = []
        line_min_values = []
        line_max_labels = []
        line_min_labels = []
        @lines.each do |x_values, y_values, x_labels, y_labels, x_states, y_states, color|
          maximum, maximum_index = x_values.max_with_index
          line_max_values << maximum
          minimum, minimum_index = x_values.min_with_index
          line_min_values << minimum

          # If there are labels then use them directly
          if x_labels
            line_max_labels << x_labels[maximum_index]
            line_min_labels << x_labels[minimum_index]
          else # Put in max and min as place holders
            line_max_labels << maximum
            line_min_labels << minimum
          end
        end
        x_max, x_max_index = line_max_values.max_with_index
        x_min, x_min_index = line_min_values.min_with_index
        x_max_label        = line_max_labels[x_max_index]
        # If the label equals the max it was a placeholder so set to nil
        x_max_label        = nil if x_max_label == x_max
        x_min_label        = line_min_labels[x_min_index]
        # If the label equals the min it was a placeholder so set to nil
        x_min_label        = nil if x_min_label == x_min

        if x_min == x_max
          if x_min == 0.0
            x_max = 1
            x_min = -1
          else
            x_max = x_max + 1
            x_min = x_min - 1
          end
        end
      end
      return [x_min, x_max, x_min_label, x_max_label]
    end

    def get_display_text(keys, states, labels, index)
      text = nil
      text = labels[index] if labels
      if states
        text = states.key(keys[index])
        if text
          text = "#{text} (#{keys[index]})"
        end
      end
      return text
    end

    # Search through all the lines on the given left or right y axis for
    # defined states. If each line has identical states return the states
    # else return nil.
    #
    # @param [Symbol] Axis which must be :LEFT or :RIGHT
    # @return [Hash|nil] The states for the given axis or nil
    def unique_y_states(axis)
      lines = left() if axis == :LEFT
      lines = right() if axis == :RIGHT
      raise "axis must be :LEFT or :RIGHT" unless lines
      states = lines.collect{|line| line[5] }.uniq
      if states.length == 1
        return states[0]
      else
        return nil
      end
    end

    # If there is a single line defined with states the states will be
    # returned. Otherwise return nil.
    #
    # @return [Hash|nil] The states or nil
    def single_line_with_x_states
      return @lines.length == 1 && @lines[0][4]
    end

    def add_line(text, y, x = nil, y_labels = nil, x_labels = nil, y_states = nil, x_states = nil, color = 'blue', axis = :LEFT, max_points_plotted = nil)
      # Validate y data
      raise ArgumentError, "TlmGrapher y data must be given in an array-like class" unless y.respond_to?(:[])
      raise ArgumentError, "TlmGrapher y data cannot be empty" if y.empty?
      raise ArgumentError, "TlmGrapher y data must be Numeric" unless y[0].kind_of?(Numeric)

      # Validate x data
      if x.respond_to?(:[])
        raise ArgumentError, "TlmGrapher x and y data must be the same size" unless y.length == x.length
        raise ArgumentError, "TlmGrapher x data must be Numeric" unless x[0].kind_of?(Numeric)
      else
        raise ArgumentError, "TlmGrapher x data must be given in an array-like class" unless x.nil?
      end

      # Validate y_labels data
      if y_labels.respond_to?(:[])
        raise ArgumentError, "TlmGrapher y_labels and y data must be the same size" unless y.length == y_labels.length
      else
        raise ArgumentError, "TlmGrapher y_labels data must be given in an array-like class" unless y_labels.nil?
      end

      # Validate x_labels data
      if x_labels.respond_to?(:[])
        raise ArgumentError, "TlmGrapher x_labels and y data must be the same size" unless y.length == x_labels.length
      else
        raise ArgumentError, "TlmGrapher x_labels data must be given in an array-like class" unless x_labels.nil?
      end

      # Validate y_states data
      unless y_states.respond_to?(:index)
        raise ArgumentError, "TlmGrapher y_states data must be given in an hash-like class" unless y_states.nil?
      end

      # Validate x_states data
      unless x_states.respond_to?(:index)
        raise ArgumentError, "TlmGrapher x_states data must be given in an hash-like class" unless x_states.nil?
      end

      if max_points_plotted and y.length > max_points_plotted
        step = (y.length.to_f / max_points_plotted.to_f).ceil
        y_reduced = LowFragmentationArray.new(max_points_plotted + 1)
        x_reduced = nil
        x_reduced = LowFragmentationArray.new(max_points_plotted + 1) if x
        y_labels_reduced = nil
        y_labels_reduced = LowFragmentationArray.new(max_points_plotted + 1) if y_labels
        x_labels_reduced = nil
        x_labels_reduced = LowFragmentationArray.new(max_points_plotted + 1) if x_labels
        (0..(y.length - 1)).step(step) do |index|
          y_reduced        << y[index].to_f
          x_reduced        << x[index].to_f   if x_reduced
          y_labels_reduced << y_labels[index] if y_labels_reduced
          x_labels_reduced << x_labels[index] if x_labels_reduced
        end
        y_reduced        << y[-1].to_f
        x_reduced        << x[-1].to_f   if x_reduced
        y_labels_reduced << y_labels[-1] if y_labels_reduced
        x_labels_reduced << x_labels[-1] if x_labels_reduced
        y        = y_reduced
        x        = x_reduced
        y_labels = y_labels_reduced
        x_labels = x_labels_reduced
      else
        # Clone data so that we don't modify the user's data
        y        = y.clone_to_f
        x        = x.clone_to_f   if x
        y_labels = y_labels.clone if y_labels
        x_labels = x_labels.clone if x_labels
      end
      unless x
        x = (1..(y.length)).to_a_to_f
      end

      y_labels = y                         unless y_labels
      # x_labels are only set if the formatted time item is used
      y_states = y_states.clone            if y_states
      x_states = x_states.clone            if x_states

      # Update Saved Data
      @lines << [x, y, x_labels, y_labels, x_states, y_states, color, axis, text]
    end # def add_line

    private

    # @return [Array] All the lines on the left axis
    def left
      @lines.select {|line| line[7] == :LEFT}
    end
    # @return [Array] All the lines on the right axis
    def right
      @lines.select {|line| line[7] == :RIGHT}
    end

  end # class Lines

end # module Cosmos
