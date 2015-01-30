# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_objects/linegraph_data_object'

module Cosmos

  # Represents a data object on a line graph for a housekeeping telemetry item
  class HousekeepingDataObject < LinegraphDataObject

    # Value Types
    VALUE_TYPES = [:RAW, :CONVERTED]

    # Analysis Types
    ANALYSIS_TYPES = [:NONE, :DIFFERENCE, :WINDOWED_MEAN, :WINDOWED_MEAN_REMOVED, :STD_DEV, :ALLAN_DEV, :MAXIMUM, :MINIMUM, :PEAK_TO_PEAK]

    # The housekeeping telemetry item's target name (string)
    attr_reader :target_name

    # The housekeeping telemetry item's packet name (string)
    attr_reader :packet_name

    # The housekeeping telemetry item's item name (string)
    attr_reader :item_name

    # The housekeeping telemetry item's time item name (string)
    attr_accessor :time_item_name

    # The housekeeping telemetry item's formatted time item name (string)
    attr_accessor :formatted_time_item_name

    # Type of data to collect - :RAW or :CONVERTED
    attr_accessor :value_type

    # The analysis to perform
    attr_accessor :analysis

    # The number of samples to use in the analysis (integer)
    attr_reader :analysis_samples

    # Automatically show limits line for telemetry item (true or false)
    attr_reader :show_limits_lines

    # Limits lines for telemetry item (array)
    attr_accessor :limits_lines

    # Create a new data object
    def initialize
      super()
      @target_name = nil
      @packet_name = nil
      @item_name = nil
      @time_item_name = nil
      @formatted_time_item_name = nil
      @value_type = :CONVERTED
      @analysis = :NONE
      @analysis_samples = 3
      @show_limits_lines = false
      @limits_lines = []
      @num_samples_ahead = 1
      @num_samples_behind = 1
      @unprocessed_x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @unprocessed_y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @differenced_y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
    end # def initialize

    # Returns the configuration lines used to create this data object
    def configuration_string
      string = super()
      string << "      ITEM #{@target_name} #{@packet_name} #{@item_name}\n" if @target_name and @packet_name and @item_name
      string << "      TIME_ITEM #{@time_item_name}\n" if @time_item_name
      string << "      FORMATTED_TIME_ITEM #{@formatted_time_item_name}\n" if @formatted_time_item_name
      string << "      VALUE_TYPE #{@value_type}\n"
      string << "      ANALYSIS #{@analysis}\n"
      string << "      ANALYSIS_SAMPLES #{@analysis_samples}\n"
      string << "      SHOW_LIMITS_LINES #{@show_limits_lines.to_s.upcase}\n"
      string
    end # def configuration_string

    # Handles data object specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'ITEM'
        # Expect 3 parameters
        parser.verify_num_parameters(3, 3, "ITEM <Target Name> <Packet Name> <Item Name>")
        set_item(parameters[0], parameters[1], parameters[2], true)

      when 'TIME_ITEM'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "TIME_ITEM <Time Item Name>")
        @time_item_name = parameters[0].upcase

      when 'FORMATTED_TIME_ITEM'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "FORMATTED_TIME_ITEM <Formatted Time Item Name>")
        @formatted_time_item_name = parameters[0].upcase

      when 'VALUE_TYPE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "VALUE_TYPE <RAW or CONVERTED>")
        value_type = parameters[0].upcase.intern
        if VALUE_TYPES.include?(value_type)
          @value_type = value_type
        else
          raise ArgumentError, "Unknown VALUE_TYPE value: #{value_type}"
        end

      when 'ANALYSIS'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "ANALYSIS <Analysis Type>")
        analysis = parameters[0].upcase.intern
        if ANALYSIS_TYPES.include?(analysis)
          @analysis = analysis
        else
          raise ArgumentError, "Unknown ANALYSIS value: #{analysis}"
        end

      when 'ANALYSIS_SAMPLES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "ANALYSIS_SAMPLES <Number of Samples>")
        self.analysis_samples = parameters[0].to_i

      when 'SHOW_LIMITS_LINES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_LIMITS_LINES <TRUE or FALSE>")
        self.show_limits_lines = ConfigParser.handle_true_false(parameters[0])

      else
        # Unknown keywords are passed to parent data object
        super(parser, keyword, parameters)

      end # case keyword

    end # def handle_keyword

    # Returns the packet processed by this data object
    def processed_packets
      if @target_name and @packet_name
        [[@target_name, @packet_name]]
      else
        []
      end
    end

    # (see DataObject#process_packet)
    def process_packet(packet, count)
      begin
        # Retrieve x and y values from packet
        x_value = packet.read(@time_item_name)
        if @value_type == :RAW
          y_value = packet.read(@item_name, :RAW)
        else
          y_value = packet.read(@item_name)
        end
        # Bail on the values if they are NaN or nil as we can't graph them
        return if x_value.nil? || y_value.nil? ||
          (x_value.respond_to?(:nan?) && x_value.nan?) ||
          (y_value.respond_to?(:nan?) && y_value.nan?)
        @formatted_x_values << packet.read(@formatted_time_item_name) if @formatted_time_item_name

        upper_index  = nil
        sample_index = nil
        lower_index  = nil
        if @analysis != :NONE
          # Add to unprocessed data
          @unprocessed_x_values << x_value
          @unprocessed_y_values << y_value

          # Calculate indexes into arrays
          upper_index  = @unprocessed_y_values.length - 1
          sample_index = upper_index - @num_samples_ahead
          lower_index  = sample_index - @num_samples_behind
        end

        case @analysis
        when :NONE
          @x_values << x_value
          @y_values << (y_value + @y_offset)
          @plot.redraw_needed = true

        when :DIFFERENCE, :ALLAN_DEV
          if @unprocessed_y_values.length > 1
            differenced_y_value = y_value - @unprocessed_y_values[-2]

            if @analysis == :DIFFERENCE
              @x_values << x_value
              @y_values << (differenced_y_value + @y_offset)
              @plot.redraw_needed = true
            else # @analysis == :ALLAN_DEV
              @differenced_y_values[upper_index] = differenced_y_value

              if lower_index >= 1
                data = @differenced_y_values[lower_index..upper_index]
                @x_values << @unprocessed_x_values[sample_index]
                @y_values << (Math.sqrt(data.squared.sum / (@analysis_samples * 2)) + @y_offset)
                @plot.redraw_needed = true
              end
            end
          end

        when :WINDOWED_MEAN, :WINDOWED_MEAN_REMOVED, :STD_DEV
          if @unprocessed_y_values.length >= @analysis_samples
            # Isolate window of data
            data = @unprocessed_y_values[lower_index..upper_index]

            # Calculate windowed mean
            mean = data.mean

            case @analysis
            when :WINDOWED_MEAN
              @y_values << (mean + @y_offset)
            when :WINDOWED_MEAN_REMOVED
              @y_values << (@unprocessed_y_values[sample_index] - mean + @y_offset)
            when :STD_DEV
              data.map! {|value| value - mean}
              @y_values << (Math.sqrt(data.squared.sum / (@analysis_samples - 1)) + @y_offset)
            end
            @x_values << @unprocessed_x_values[sample_index]
            @plot.redraw_needed = true
          end

        when :MAXIMUM, :MINIMUM, :PEAK_TO_PEAK
          if @unprocessed_y_values.length >= @analysis_samples
            case @analysis
            when :MAXIMUM
              @y_values << (@unprocessed_y_values[lower_index..upper_index].max + @y_offset)
            when :MINIMUM
              @y_values << (@unprocessed_y_values[lower_index..upper_index].min + @y_offset)
            else # :PEAK_TO_PEAK
              @y_values << ((@unprocessed_y_values[lower_index..upper_index].max - @unprocessed_y_values[lower_index..upper_index].min) + @y_offset)
            end
            @x_values << @unprocessed_x_values[sample_index]
            @plot.redraw_needed = true
          end

        end # case @analysis

        # Make sure the data object's first x value is the smallest x value encountered during packet processing.
        # This is the smallest x_value seen since reset() was called, i.e. it doesn't get deleted during pruning.
        # We make the assumption that @x_values is ordered, so just check against its first value.
        if (@x_values.length > 0) and (@x_values[0] < @first_x_value)
          @first_x_value = @x_values[0]
        end

        # Prune Data
        prune_to_max_points_saved()
      rescue Exception => error
        raise error if error.class == NoMemoryError
        reset()
        @error = error
        @plot.redraw_needed = true
        if error.is_a? TypeError
          @error = FatalError.new("Telemetry point #{packet.target_name} #{packet.packet_name} #{@item_name} could not be displayed. This is most likely due to this telemetry point being a String which can't be represented on the graph. Remove the point from the list of telemetry items to cause this exception to go away.\n\n#{error}")
        end
      end
    end # def process_packet

    # Returns the name of this data object
    def name
      if @target_name and @packet_name and @item_name
        if @analysis != :NONE
          "#{@target_name} #{@packet_name} #{@item_name} (#{@analysis})"
        else
          "#{@target_name} #{@packet_name} #{@item_name}"
        end
      else
        ''
      end
    end

    # Resets the data object
    def reset
      super()
      @unprocessed_x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @unprocessed_y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @differenced_y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
    end

    # Creates a copy of the data object with settings but without data
    def copy
      data_object = super()
      if @target_name and @packet_name and @item_name
        data_object.set_item(@target_name.clone, @packet_name.clone, @item_name.clone)
      end
      data_object.time_item_name = @time_item_name.clone if @time_item_name
      data_object.formatted_time_item_name = @formatted_time_item_name.clone if @formatted_time_item_name
      data_object.value_type = @value_type
      data_object.analysis = @analysis
      data_object.analysis_samples = @analysis_samples
      data_object.show_limits_lines = @show_limits_lines
      if @target_name
        limits_lines = []
        get_limits_lines()
        @limits_lines.each do |y_value, color|
          limits_lines << [y_value, color.clone]
        end
        data_object.limits_lines = limits_lines
      end
      data_object
    end

    # Edits the data object - show_limits_lines is the only edit_safe? attribute
    def edit(editted_data_object)
      self.show_limits_lines = editted_data_object.show_limits_lines
      super(editted_data_object)
    end

    # Determines if changes can be made to the data object without affecting data
    #
    # @param edited_data_object [DataObject] The data object which was edited
    def edit_safe?(editted_data_object)
      if @target_name != editted_data_object.target_name or
         @packet_name != editted_data_object.packet_name or
         @item_name != editted_data_object.item_name or
         @time_item_name != editted_data_object.time_item_name or
         @formatted_time_item_name != editted_data_object.formatted_time_item_name or
         @value_type != editted_data_object.value_type or
         @analysis != editted_data_object.analysis or
         @analysis_samples != editted_data_object.analysis_samples
        false
      else
        super(editted_data_object)
      end
    end

    # Sets the housekeeping item
    def set_item(target_name, packet_name, item_name, during_configuration = false)
      @target_name = target_name
      @packet_name = packet_name
      @item_name = item_name
      _, item = System.telemetry.packet_and_item(@target_name, @packet_name, @item_name)
      @y_states = item.states
      if @y_states
        @value_type = :RAW
      else
        @value_type = :CONVERTED unless during_configuration
      end

      @time_item_name = 'RECEIVED_TIMESECONDS' unless @time_item_name

      # Update limits lines
      self.show_limits_lines = @show_limits_lines
    end

    # Sets the number of analysis samples
    def analysis_samples=(new_analysis_samples)
      # Value must be at least 2
      if new_analysis_samples <= 1
        raise ArgumentError, "Invalid ANALYSIS_SAMPLES value: #{new_analysis_samples}"
      else
        @analysis_samples = new_analysis_samples
        if @analysis_samples % 2 == 0
          # Even
          @num_samples_ahead  = @analysis_samples / 2
          @num_samples_behind = @num_samples_ahead - 1
        else
          # Odd
          @num_samples_ahead  = (@analysis_samples - 1) / 2
          @num_samples_behind = @num_samples_ahead
        end
      end
    end

    # Sets the show limits lines flag
    def show_limits_lines=(new_show_limits_lines)
      @show_limits_lines = new_show_limits_lines
      get_limits_lines()
    end

    protected

    def get_limits_lines
      if @target_name
        _, item = System.telemetry.packet_and_item(@target_name, @packet_name, @item_name)
        if item.limits.values
          @limits_lines = []
          @limits_lines << [item.limits.values[:DEFAULT][0], 'red']
          @limits_lines << [item.limits.values[:DEFAULT][1], 'yellow']
          if item.limits.values[:DEFAULT].length == 6
            @limits_lines << [item.limits.values[:DEFAULT][4], 'green']
            @limits_lines << [item.limits.values[:DEFAULT][5], 'green']
          end
          @limits_lines << [item.limits.values[:DEFAULT][2], 'yellow']
          @limits_lines << [item.limits.values[:DEFAULT][3], 'red']
        end
      end
    end

    # (see DataObject#prune_to_max_points_saved)
    def prune_to_max_points_saved(force_prune = false)
      prune_index = super(force_prune)
      if prune_index
        # Prune unprocessed
        unless @unprocessed_x_values.empty?
          @unprocessed_x_values.remove_before!(prune_index)
          @unprocessed_y_values.remove_before!(prune_index)
          @differenced_y_values.remove_before!(prune_index) if @analysis == :ALLAN_DEV
        end
      end
      prune_index
    end

  end # class HousekeepingDataObject

end # module Cosmos
