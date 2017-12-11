# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_objects/data_object'

module Cosmos
  # Represents a data object on a line graph
  # Designed for use as a base class for custom data objects
  class LinegraphDataObject < DataObject

    # Possible Y-Axis Selections
    Y_AXIS_CHOICES = [:LEFT, :RIGHT]

    # Horizontal lines associated with this data object
    # Typically used to display limits on the line graph
    # Array of arrays of the form [y_value,  color]
    attr_accessor :horizontal_lines

    # Y offset applied to each of the data object's values (float)
    attr_accessor :y_offset

    # Y axis used for this data object - :LEFT or :RIGHT
    attr_accessor :y_axis

    # Array of x_values to graph on the line graph
    attr_accessor :x_values

    # Array of y values to graph on the line graph
    attr_accessor :y_values

    # Array of formatted x_values to graph on the line graph
    attr_accessor :formatted_x_values

    # Hash of x states
    attr_accessor :x_states

    # Hash of y states
    attr_accessor :y_states

    # Create a new LineGraphDataObject
    def initialize
      super()
      @horizontal_lines = []
      @y_offset = 0.0
      @y_axis = :LEFT
      @x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @formatted_x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @x_states = nil
      @y_states = nil
    end # def initialize

    # Returns the configuration lines used to create this data object
    def configuration_string
      string = super()
      string << "      Y_OFFSET #{@y_offset}\n" if @y_offset != 0.0
      string << "      Y_AXIS #{@y_axis}\n"
      @horizontal_lines.each do |y_value, color|
        string << "      HORIZONTAL_LINE #{y_value} #{color}\n"
      end
      string
    end # def configuration_string

    # Handles data object specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'HORIZONTAL_LINE'
        # Expect 2 parameters
        parser.verify_num_parameters(2, 2, "HORIZONTAL_LINE <Y Value> <Color>")
        y_value = parameters[0].to_f
        color = parameters[1]
        @horizontal_lines << [y_value, color]

      when 'Y_OFFSET'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "Y_OFFSET <Offset Value>")
        @y_offset = parameters[0].to_f

      when 'Y_AXIS'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "Y_AXIS <LEFT or RIGHT>")
        axis = parameters[0].upcase.intern
        if Y_AXIS_CHOICES.include?(axis)
          @y_axis = axis
        else
          raise ArgumentError, "Unknown Y_AXIS value: #{axis}"
        end

      else
        # Unknown keywords are passed to parent data object
        super(parser, keyword, parameters)

      end # case keyword

    end # def handle_keyword

    # Resets the line graph data object
    def reset
      super()
      @x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @formatted_x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
    end

    # Exports the data objects data
    def export
      if @formatted_x_values.empty?
        [[name().clone, 'X'].concat(@x_values), [name().clone, 'Y'].concat(@y_values)]
      else
        [[name().clone, 'Formatted X'].concat(@formatted_x_values), [name().clone, 'X'].concat(@x_values), [name().clone, 'Y'].concat(@y_values)]
      end
    end

    # Creates a copy of the data object with settings but without data
    def copy
      data_object = super()
      horizontal_lines = []
      @horizontal_lines.each do |y_value, color|
        horizontal_lines << [y_value, color.clone]
      end
      data_object.horizontal_lines = horizontal_lines
      data_object.y_offset = @y_offset
      data_object.y_axis = @y_axis

      # States should not be changing, so they will not be deep cloned.
      data_object.x_states = @x_states.clone if @x_states
      data_object.y_states = @y_states.clone if @y_states

      data_object
    end

    # Edits the data object
    def edit(edited_data_object)
      super(edited_data_object)
      @horizontal_lines = edited_data_object.horizontal_lines
      if @y_offset != edited_data_object.y_offset
        old_y_offset = @y_offset
        new_y_offset = edited_data_object.y_offset
        @y_values.length.times {|index| @y_values[index] += (new_y_offset - old_y_offset)}
      end
      @y_offset = edited_data_object.y_offset
      @y_axis = edited_data_object.y_axis
      @x_states = edited_data_object.x_states
      @y_states = edited_data_object.y_states
    end

    protected

    # (see DataObject#prune_to_max_points_saved)
    def prune_to_max_points_saved(force_prune = false)
      prune_index = nil
      if @max_points_saved
        prune_index = @x_values.length - @max_points_saved
        if prune_index > @prune_hysterisis or (force_prune and prune_index > 0)
          @x_values.remove_before!(prune_index)
          @y_values.remove_before!(prune_index)
          @formatted_x_values.remove_before!(prune_index)
        else
          prune_index = nil
        end
      end
      prune_index
    end
  end
end
