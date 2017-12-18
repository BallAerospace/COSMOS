# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  # Represents a data object in a tabbed plots definition
  # Designed for use as a base class for custom data objects
  class DataObject

    # List of colors to use
    COLOR_LIST = %w(blue red green darkorange gold purple hotpink lime cornflowerblue brown coral crimson indigo tan lightblue cyan peru)

    # Used to create large arrays to prevent memory thrashing with large objects
    DEFAULT_ARRAY_SIZE = 100000

    # Percent of max seconds saved to achieve hystersis on pruning to
    # reduce memory thrashing
    PRUNE_HYSTERISIS_PERCENTAGE = 0.10

    # Plot holding this data object (subclass of Plot)
    attr_accessor :plot

    # Name of this data object (string or nil)
    attr_writer :name

    # Max number of data points saved (integer)
    attr_reader :max_points_saved

    # Type of data object (string)
    attr_accessor :data_object_type

    # Error associated with this data_object (Exception)
    attr_accessor :error

    # Color currently being used to draw the line (string)
    attr_accessor :color

    # Assigned Color of the line (string or nil for auto color choice)
    attr_accessor :assigned_color

    # This value is the first x value for this data object since reset() was called. It is stored here
    # so it can be retrieved even after x values have been pruned.
    attr_accessor :first_x_value

    def initialize
      @plot = nil
      @max_points_saved = nil
      @prune_hysterisis = nil
      # Start this value at the max float so any x_value will be less than it
      @first_x_value = Float::MAX
      @error = nil
      @assigned_color = nil
      @color = COLOR_LIST[0]

      # Type is classname without DataObject
      @data_object_type = self.class.to_s[0..-11].upcase
      @data_object_type = @data_object_type.split("::")[-1] # remove Cosmos:: if necessary
    end # def initialize

    # Returns the configuration lines used to create this data object
    def configuration_string
      string  = "    DATA_OBJECT #{@data_object_type}\n"
      string << "      COLOR #{@assigned_color}\n" if @assigned_color
      string
    end # def configuration_string

    # Handles data object specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'COLOR'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "COLOR <Color Name>")
        @assigned_color = parameters[0].downcase
        @color = @assigned_color
      else
        raise ArgumentError, "Unknown keyword received by #{self.class}: #{keyword}"
      end
    end # def handle_keyword

    # Returns the packets processed by this data object as an array of
    # [target_name, packet_name] pairs
    def processed_packets
      raise "processed_packets must be defined by class #{self.class}"
    end

    # Processes a packet associated with this data object
    #
    # @param packet [Packet] The packet to process
    # @param count [Integer] Count which increments for each packet received by
    #   the higher level process
    def process_packet(packet, count)
      raise "process_packet must be defined by class #{self.class}"
    end

    def handle_process_exception(error, telemetry_point)
      raise error if error.class == NoMemoryError
      reset()
      @plot.redraw_needed = true
      @error = error
      if error.is_a? TypeError
        @error = FatalError.new("Telemetry point #{telemetry_point} could not be displayed. This is most likely due to this telemetry point being a String which can't be represented on the graph. Remove the point from the list of telemetry items to cause this exception to go away.\n\n#{error}")
      else
        @exceptions_reported ||= []
        unless @exceptions_reported.include?(error.message)
          @exceptions_reported << error.message
          Cosmos.write_exception_file(error)
        end
      end
    end

    # Resets the data object's data (everything that is not configuration)
    def reset
      @error = nil
      # Reset this value at the max float so any x_value will be less than it
      @first_x_value = Float::MAX
    end

    # Supplies text that should be appended to the popup string on mousing over the specified
    # x value
    def popup_modifier(x_value)
      # The default class returns an empty value
      return ""
    end

    # Exports the data object's data as an array of arrays.  Each inner array
    # is a column of the output.
    def export
      raise "export must be defined by class #{self.class}"
    end

    # Creates a copy of the data object with settings but without data
    def copy
      data_object = self.class.new
      data_object.assigned_color = @assigned_color.clone if @assigned_color
      data_object.color = @color.clone
      data_object.max_points_saved = @max_points_saved
      data_object
    end

    # Edits the data object by updating its settings from another data object
    def edit(edited_data_object)
      @assigned_color = edited_data_object.assigned_color
      @color = edited_data_object.color
      self.max_points_saved = edited_data_object.max_points_saved
    end

    # Indicates if the changes made to the data object are safe to perform without reseting
    # its data
    #
    # @param edited_data_object [DataObject] The data object which was edited
    def edit_safe?(edited_data_object)
      true
    end

    # Returns the name of this data object
    def name
      'Unknown'
    end

    # Sets the maximum number of points saved
    def max_points_saved=(new_max_points_saved)
      @max_points_saved = new_max_points_saved
      if @max_points_saved
        @prune_hysterisis  = (@max_points_saved.to_f * PRUNE_HYSTERISIS_PERCENTAGE).to_i
        @prune_hysterisis = 0 if @prune_hysterisis < 0
        prune_to_max_points_saved(true) # force prune
      else
        @prune_hysterisis  = nil
      end
    end

    # Prunes data to max_points_saved
    #
    # @param force_prune [Boolean] Whether to prune no matter if the
    #   PRUNE_HYSTERISIS_PERCENTAGE is met. Set to true if the max_points_saved
    #   is changed to ensure the total is within the new limit.
    def prune_to_max_points_saved(force_prune = false)
      # Must be implemented by subclasses
      return nil
    end

    # @return [Boolean] Whether the value is invalid: nil, NaN, or Infinite
    #   and thus can not be graphed
    def invalid_value?(value)
      invalid = false
      invalid ||= value.nil?
      invalid ||= (value.respond_to?(:nan?) && value.nan?)
      invalid ||= (value.respond_to?(:infinite?) && value.infinite?)
      invalid
    end
  end
end
