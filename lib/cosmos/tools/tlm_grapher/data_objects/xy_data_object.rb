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

  # Represents a data object on an XyGraph for two telemetry items
  class XyDataObject < DataObject

    # Value Types
    VALUE_TYPES = [:RAW, :CONVERTED]

    # The target name (string)
    attr_accessor :target_name

    # The packet name (string)
    attr_accessor :packet_name

    # The x item name (string)
    attr_reader :x_item_name

    # The y item name (string)
    attr_reader :y_item_name

    # The time item name (string)
    attr_reader :time_item_name

    # Type of data to collect for x value - :RAW or :CONVERTED
    attr_accessor :x_value_type

    # Type of data to collect for y value - :RAW or :CONVERTED
    attr_accessor :y_value_type

    # Array of x_values to graph on the line graph
    attr_accessor :x_values

    # Array of y values to graph on the line graph
    attr_accessor :y_values

    # Array of time values to graph on the line graph
    attr_accessor :time_values

    # Hash of x states
    attr_accessor :x_states

    # Hash of y states
    attr_accessor :y_states

    def initialize
      super()

      @target_name = nil
      @packet_name = nil
      @x_item_name = nil
      @y_item_name = nil
      @time_item_name = nil
      @x_value_type = :CONVERTED
      @y_value_type = :CONVERTED

      @x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @time_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @x_states = nil
      @y_states = nil

      @during_configuration = false
    end

    # Returns the configuration lines used to create this data object
    def configuration_string
      string = super()
      string << "      TARGET #{@target_name}\n" if @target_name
      string << "      PACKET #{@packet_name}\n" if @packet_name
      string << "      X_ITEM #{@x_item_name}\n" if @x_item_name
      string << "      Y_ITEM #{@y_item_name}\n" if @y_item_name
      string << "      TIME_ITEM #{@time_item_name}\n" if @time_item_name
      string << "      X_VALUE_TYPE #{@x_value_type}\n"
      string << "      Y_VALUE_TYPE #{@y_value_type}\n"
      string
    end # def configuration_string

    # Handles data object specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'TARGET'
        # Expect 1 parameters
        parser.verify_num_parameters(1, 1, "TARGET <Target Name>")
        unless @target_name
          @target_name = parameters[0].upcase
        else
          raise ArgumentError, "Only one TARGET may be associated with an #{self.class}"
        end

      when 'PACKET'
        # Expect 1 parameters
        parser.verify_num_parameters(1, 1, "PACKET <Packet Name>")
        unless @packet_name
          @packet_name = parameters[0].upcase
        else
          raise ArgumentError, "Only one PACKET may be associated with an #{self.class}"
        end

      when 'X_ITEM'
        # Expect 1 parameters
        parser.verify_num_parameters(1, 1, "X_ITEM <X Item Name>")
        unless @x_item_name
          @during_configuration = true
          self.x_item_name = parameters[0]
          @during_configuration = false
        else
          raise ArgumentError, "Only one X_ITEM may be associated with an #{self.class}"
        end

      when 'Y_ITEM'
        # Expect 1 parameters
        parser.verify_num_parameters(1, 1, "Y_ITEM <Y Item Name>")
        unless @y_item_name
          @during_configuration = true
          self.y_item_name = parameters[0]
          @during_configuration = false
        else
          raise ArgumentError, "Only one Y_ITEM may be associated with an #{self.class}"
        end

      when 'TIME_ITEM'
        # Expect 1 parameters
        parser.verify_num_parameters(1, 1, "TIME_ITEM <Time Item Name>")
        if @time_item_name and not @y_item_name
          raise ArgumentError, "Only one TIME_ITEM may be associated with an #{self.class}"
        else
          self.time_item_name = parameters[0]
        end

      when 'X_VALUE_TYPE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "X_VALUE_TYPE <RAW or CONVERTED>")
        value_type = parameters[0].upcase.intern
        if VALUE_TYPES.include?(value_type)
          @x_value_type = value_type
        else
          raise ArgumentError, "Unknown X_VALUE_TYPE value: #{value_type}"
        end

      when 'Y_VALUE_TYPE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "Y_VALUE_TYPE <RAW or CONVERTED>")
        value_type = parameters[0].upcase.intern
        if VALUE_TYPES.include?(value_type)
          @y_value_type = value_type
        else
          raise ArgumentError, "Unknown Y_VALUE_TYPE value: #{value_type}"
        end

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
        # Retrieve x, y, and time values from packet
        if @x_value_type == :RAW
          x_value = packet.read(@x_item_name, :RAW)
        else
          x_value = packet.read(@x_item_name)
        end
        if @y_value_type == :RAW
          y_value = packet.read(@y_item_name, :RAW)
        else
          y_value = packet.read(@y_item_name)
        end

        # Bail on the values if they are NaN or nil as we can't graph them
        return if x_value.nil? || y_value.nil? ||
          (x_value.respond_to?(:nan?) && x_value.nan?) ||
          (y_value.respond_to?(:nan?) && y_value.nan?) ||
          (x_value.respond_to?(:infinite?) && x_value.infinite?) ||
          (y_value.respond_to?(:infinite?) && y_value.infinite?)

        time_value = packet.read(@time_item_name) if @time_item_name

        @x_values << x_value
        @y_values << y_value
        @time_values << time_value if @time_item_name

        @plot.redraw_needed = true

        # Prune Data
        prune_to_max_points_saved()
      rescue Exception => error
        handle_process_exception(error, "#{packet.target_name} #{packet.packet_name} #{@x_item_name} or #{@y_item_name}")
      end
    end # def process_packet

    # Returns the name of this data object
    def name
      if @target_name and @packet_name and @y_item_name and @x_item_name
        "#{@target_name} #{@packet_name} #{@y_item_name} VS #{@x_item_name}"
      else
        ""
      end
    end

    # Resets the data object
    def reset
      super()
      @x_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @y_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE)
      @time_values = LowFragmentationArray.new(DEFAULT_ARRAY_SIZE) if @time_item_name
    end

    # Exports the data objects data
    def export
      if @time_item_name
        [[name().clone, 'Time'].concat(@time_values), [name().clone, 'X'].concat(@x_values), [name().clone, 'Y'].concat(@y_values)]
      else
        [[name().clone, 'X'].concat(@x_values), [name().clone, 'Y'].concat(@y_values)]
      end
    end

    # Creates a copy of the data object with settings but without data
    def copy
      data_object = super()
      data_object.target_name = @target_name.clone if @target_name
      data_object.packet_name = @packet_name.clone if @packet_name
      data_object.x_item_name = @x_item_name.clone if @x_item_name
      data_object.y_item_name = @y_item_name.clone if @y_item_name
      data_object.time_item_name = @time_item_name.clone if @time_item_name
      data_object.x_value_type = @x_value_type
      data_object.y_value_type = @y_value_type
      data_object
    end

    # Determines if changes can be made to the data object without affecting data
    #
    # @param edited_data_object [DataObject] The data object which was edited
    def edit_safe?(editted_data_object)
      if @target_name != editted_data_object.target_name or
         @packet_name != editted_data_object.packet_name or
         @x_item_name != editted_data_object.x_item_name or
         @y_item_name != editted_data_object.y_item_name or
         @time_item_name != editted_data_object.time_item_name or
         @x_value_type != editted_data_object.x_value_type or
         @y_value_type != editted_data_object.y_value_type
        false
      else
        super(editted_data_object)
      end
    end

    # Sets x item
    def x_item_name=(x_item_name)
      @x_item_name = x_item_name
      _, item = System.telemetry.packet_and_item(@target_name, @packet_name, @x_item_name)
      @x_states = item.states
      if @x_states
        @x_value_type = :RAW
      else
        @x_value_type = :CONVERTED unless @during_configuration
      end
    end

    # Sets y item
    def y_item_name=(y_item_name)
      @y_item_name = y_item_name
      _, item = System.telemetry.packet_and_item(@target_name, @packet_name, @y_item_name)
      @y_states = item.states
      if @y_states
        @y_value_type = :RAW
      else
        @y_value_type = :CONVERTED unless @during_configuration
      end

      @time_item_name = 'RECEIVED_TIMESECONDS' if !@time_item_name
    end

    # Sets time item
    def time_item_name=(time_item_name)
      @time_item_name = time_item_name
      System.telemetry.packet_and_item(@target_name, @packet_name, @time_item_name)
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
          @time_values.remove_before!(prune_index)
        else
          prune_index = nil
        end
      end
      prune_index
    end

  end # class XyDataObject

end # module Cosmos
