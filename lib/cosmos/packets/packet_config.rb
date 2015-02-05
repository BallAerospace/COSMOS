# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet'
require 'cosmos/packets/packet_item_parser'
require 'cosmos/conversions'
require 'cosmos/processors'
require 'ostruct'

module Cosmos

  class PacketConfig
    # @return [String] The name of this configuration. To be used by higher
    #   level classes to store information about the current PacketConfig.
    attr_accessor :name

    # @return [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    attr_reader :telemetry

    # @return [Hash<String=>Packet>] Hash of all the command packets
    #   keyed by the packet name.
    attr_reader :commands

    # @return [Hash<String=>Array(String, String, String)>] Hash of all the
    #   limits groups keyed by the group name. The value is a three element
    #   array consisting of the target_name, packet_name, and item_name.
    attr_reader :limits_groups

    # @return [Array<Symbol>] The defined limits sets for all items in the
    #   packet. This will always include :DEFAULT.
    attr_reader :limits_sets

    # @return [Array<String>] Array of strings listing all the warnings
    #   that were created while parsing the configuration file.
    attr_reader :warnings

    # @return [Hash<String=>Hash<String=>Array(Packet)>>] Hash of hashes keyed
    #   first by the target name and then by the item name. This results in an
    #   array of packets containing that target and item. This structure is
    #   used to perform lookups when the packet and item are known but the
    #   packet is not.
    attr_reader :latest_data

    def initialize
      @name = nil
      @telemetry = {}
      @commands = {}
      @limits_groups = {}
      @limits_sets = [:DEFAULT]
      # Hash of Hashes. First index by target name and then item name.
      # Returns an array of packets with that target and item.
      @latest_data = {}
      @warnings = []

      # Create unknown packets
      @commands['UNKNOWN']
      @commands['UNKNOWN'] = {}
      @commands['UNKNOWN']['UNKNOWN'] = Packet.new('UNKNOWN', 'UNKNOWN', :BIG_ENDIAN)
      @telemetry['UNKNOWN']
      @telemetry['UNKNOWN'] = {}
      @telemetry['UNKNOWN']['UNKNOWN'] = Packet.new('UNKNOWN', 'UNKNOWN', :BIG_ENDIAN)

      # Used during packet processing
      @current_target_name = nil
      @current_packet_name = nil
      @current_cmd_or_tlm = nil
      @current_packet = nil
      @current_item = nil
      @current_limits_group = nil
    end

    #########################################################################
    # The following methods process a command or telemetry packet config file
    #########################################################################

    # Processes a COSMOS configuration file and uses the keywords to build up
    # knowledge of the commands, telemetry, and limits groups.
    #
    # @param filename [String] The name of the configuration file
    # @param target_name [String] The target name
    def process_file(filename, target_name)
      @converted_type = nil
      @converted_bit_size = nil
      @proc_text = ''
      @building_generic_conversion = false
      @macro_append = OpenStruct.new
      @macro_append.building = false
      @macro_append.list = []
      @macro_append.indices = []
      @macro_append.format = ''
      @macro_append.format_order = ''

      target_name = target_name.upcase

      parser = ConfigParser.new("https://github.com/BallAerospace/COSMOS/wiki/Command-and-Telemetry-Configuration")
      parser.parse_file(filename) do |keyword, params|

        if @building_generic_conversion
          case keyword
          # Complete a generic conversion
          when 'GENERIC_READ_CONVERSION_END', 'GENERIC_WRITE_CONVERSION_END'
            parser.verify_num_parameters(0, 0, keyword)
            @current_item.read_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "READ"
            @current_item.write_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "WRITE"
            @building_generic_conversion = false
          # Add the current config.line to the conversion being built
          else
            @proc_text << parser.line << "\n"
          end # case keyword

        else # not building generic conversion

          case keyword

          # Start a new packet
          when 'COMMAND', 'TELEMETRY'
            process_packet(parser, keyword, params, target_name)

          # Select an existing packet for editing
          when 'SELECT_COMMAND', 'SELECT_TELEMETRY'
            usage = "#{keyword} <TARGET NAME> <PACKET NAME>"
            finish_packet()
            parser.verify_num_parameters(2, 2, usage)
            @current_target_name = target_name
            @current_target_name = params[0].upcase if target_name == 'SYSTEM'
            @current_packet_name = params[1].upcase

            @current_packet = nil
            if keyword.include?('COMMAND')
              @current_cmd_or_tlm = 'Command'
              if @commands[@current_target_name]
                @current_packet = @commands[@current_target_name][@current_packet_name]
              end
            else
              @current_cmd_or_tlm = 'Telemetry'
              if @telemetry[@current_target_name]
                @current_packet = @telemetry[@current_target_name][@current_packet_name]
              end
            end
            raise parser.error("Packet not found", usage) unless @current_packet

          # Start the creation of a new limits group
          when 'LIMITS_GROUP'
            usage = "LIMITS_GROUP <GROUP NAME>"
            parser.verify_num_parameters(1, 1, usage)
            @current_limits_group = params[0].to_s.upcase
            @limits_groups[@current_limits_group] = [] unless @limits_groups.include?(@current_limits_group)

          # Add a telemetry item to the limits group
          when 'LIMITS_GROUP_ITEM'
            usage = "LIMITS_GROUP_ITEM <TARGET NAME> <PACKET NAME> <ITEM NAME>"
            parser.verify_num_parameters(3, 3, usage)
            @limits_groups[@current_limits_group] << [params[0].to_s.upcase, params[1].to_s.upcase, params[2].to_s.upcase] if @current_limits_group

          #######################################################################
          # All the following keywords must have a current packet defined
          #######################################################################
          when 'SELECT_ITEM', 'SELECT_PARAMETER', 'ITEM', 'PARAMETER', 'ID_ITEM', 'ID_PARAMETER', 'ARRAY_ITEM', 'ARRAY_PARAMETER', 'APPEND_ITEM', 'APPEND_PARAMETER', 'APPEND_ID_ITEM', 'APPEND_ID_PARAMETER', 'APPEND_ARRAY_ITEM', 'APPEND_ARRAY_PARAMETER', 'MACRO_APPEND_START', 'MACRO_APPEND_END', 'ALLOW_SHORT', 'HAZARDOUS', 'PROCESSOR', 'META', 'DISABLE_MESSAGES', 'HIDDEN', 'DISABLED'
            raise parser.error("No current packet for #{keyword}") unless @current_packet
            process_current_packet(parser, keyword, params)

          #######################################################################
          # All the following keywords must have a current item defined
          #######################################################################
          when 'STATE', 'READ_CONVERSION', 'WRITE_CONVERSION', 'POLY_READ_CONVERSION', 'POLY_WRITE_CONVERSION', 'SEG_POLY_READ_CONVERSION', 'SEG_POLY_WRITE_CONVERSION', 'GENERIC_READ_CONVERSION_START', 'GENERIC_WRITE_CONVERSION_START', 'REQUIRED', 'LIMITS', 'LIMITS_RESPONSE', 'UNITS', 'FORMAT_STRING', 'DESCRIPTION', 'MINIMUM_VALUE', 'MAXIMUM_VALUE', 'DEFAULT_VALUE', 'OVERFLOW'
            raise parser.error("No current item for #{keyword}") unless @current_item
            process_current_item(parser, keyword, params)

          else
            # blank config.lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword '#{keyword}'") if keyword
          end # case keyword

        end # if building_generic_conversion
      end

      # Complete the last defined packet
      finish_packet()
    end

    protected

    def process_current_packet(parser, keyword, params)
      case keyword

      # Select an item in the current telemetry packet for editing
      when 'SELECT_PARAMETER', 'SELECT_ITEM'
        if (@current_cmd_or_tlm == 'Command') && (keyword.split('_')[1] == 'ITEM')
          raise parser.error("SELECT_ITEM only applies to telemetry packets")
        end
        if (@current_cmd_or_tlm == 'Telemetry') && (keyword.split('_')[1] == 'PARAMETER')
          raise parser.error("SELECT_PARAMETER only applies to command packets")
        end
        usage = "#{keyword} <#{keyword.split('_')[1]} NAME>"
        finish_item()
        parser.verify_num_parameters(1, 1, usage)
        begin
          @current_item = @current_packet.get_item(params[0])
        rescue # Rescue the default execption to provide a nicer error message
          raise parser.error("#{params[0]} not found in #{@current_cmd_or_tlm.downcase} packet #{@current_target_name} #{@current_packet_name}", usage)
        end

      # Start a new telemetry item in the current packet
      when 'ITEM', 'PARAMETER', 'ID_ITEM', 'ID_PARAMETER', 'ARRAY_ITEM', 'ARRAY_PARAMETER', 'APPEND_ITEM', 'APPEND_PARAMETER', 'APPEND_ID_ITEM', 'APPEND_ID_PARAMETER', 'APPEND_ARRAY_ITEM', 'APPEND_ARRAY_PARAMETER'
        start_item(parser)

      # Start the creation of a macro-expanded list of items
      # This simulates an array of structures of multiple items in the packet by repeating
      # each item in the list multiple times with a different "index" added to the name.
      when 'MACRO_APPEND_START'
        process_macro_append_start(parser, keyword, params)

      # End the creation of a macro-expanded list of items
      when 'MACRO_APPEND_END'
        process_macro_append_end(parser, keyword) # no params for END

      # Allow this packet to be received with less data than the defined length
      # without generating a warning.
      when 'ALLOW_SHORT'
        @current_packet.short_buffer_allowed = true

      # Mark the current command as hazardous
      when 'HAZARDOUS'
        usage = "HAZARDOUS <HAZARDOUS DESCRIPTION (Optional)>"
        parser.verify_num_parameters(0, 1, usage)
        @current_packet.hazardous = true
        @current_packet.hazardous_description = params[0] if params[0]

      # Define a processor class that will be called once when a packet is received
      when 'PROCESSOR'
        process_processor(parser, keyword, params)

      when 'DISABLE_MESSAGES'
        usage = "#{keyword}"
        parser.verify_num_parameters(0, 0, usage)
        @current_packet.messages_disabled = true

      # Store user defined metadata for the packet or a packet item
      when 'META'
        usage = "META <META NAME> <META VALUES (optional)>"
        parser.verify_num_parameters(1, nil, usage)
        if params.length > 1
          meta_values = params[1..-1]
        else
          meta_values = []
        end
        if @current_item
          # Item META
          @current_item.meta[params[0].to_s.upcase] = meta_values
        else
          # Packet META
          @current_packet.meta[params[0].to_s.upcase] = meta_values
        end

      when 'HIDDEN'
        usage = "#{keyword}"
        parser.verify_num_parameters(0, 0, usage)
        @current_packet.hidden = true

      when 'DISABLED'
        usage = "#{keyword}"
        parser.verify_num_parameters(0, 0, usage)
        @current_packet.hidden = true
        @current_packet.disabled = true

      end
    end

    def process_current_item(parser, keyword, params)
      case keyword

      # Add a state to the current telemety item
      when 'STATE'
        process_state(parser, keyword, params)

      # Apply a conversion to the current item after it is read to or
      # written from the packet
      when 'READ_CONVERSION', 'WRITE_CONVERSION'
        usage = "#{keyword} <conversion class filename> <custom parameters> ..."
        parser.verify_num_parameters(1, nil, usage)
        begin
          # require should be performed in target.txt
          klass = params[0].filename_to_class_name.to_class
          raise parser.error("#{params[0].filename_to_class_name} class not found. Did you require the file in target.txt?", usage) unless klass
          @current_item.send("#{keyword.downcase}=".to_sym,
            klass.new(*params[1..(params.length - 1)]))
        rescue Exception => err
          raise parser.error(err)
        end

      # Apply a polynomial conversion to the current item
      when 'POLY_READ_CONVERSION', 'POLY_WRITE_CONVERSION'
        usage = "#{keyword} <C0> <C1> <C2> ..."
        parser.verify_num_parameters(1, nil, usage)
        @current_item.read_conversion = PolynomialConversion.new(params) if keyword.include? "READ"
        @current_item.write_conversion = PolynomialConversion.new(params) if keyword.include? "WRITE"

      # Apply a segmented polynomial conversion to the current item
      # after it is read from the telemetry packet
      when 'SEG_POLY_READ_CONVERSION'
        usage = "SEG_POLY_READ_CONVERSION <Lower Bound> <C0> <C1> <C2> ..."
        parser.verify_num_parameters(2, nil, usage)
        if !(@current_item.read_conversion &&
             SegmentedPolynomialConversion === @current_item.read_conversion)
          @current_item.read_conversion = SegmentedPolynomialConversion.new
        end
        @current_item.read_conversion.add_segment(params[0].to_f, *params[1..-1])

      # Apply a segmented polynomial conversion to the current item
      # before it is written to the telemetry packet
      when 'SEG_POLY_WRITE_CONVERSION'
        usage = "SEG_POLY_WRITE_CONVERSION <Lower Bound> <C0> <C1> <C2> ..."
        parser.verify_num_parameters(2, nil, usage)
        if !(@current_item.write_conversion &&
             SegmentedPolynomialConversion === @current_item.write_conversion)
          @current_item.write_conversion = SegmentedPolynomialConversion.new
        end
        @current_item.write_conversion.add_segment(params[0].to_f, *params[1..-1])

      # Start the definition of a generic conversion.
      # All config.lines following this config.line are considered part
      # of the conversion until an end of conversion marker is found
      when 'GENERIC_READ_CONVERSION_START', 'GENERIC_WRITE_CONVERSION_START'
        usage = "#{keyword} <Converted Type (optional)> <Converted Bit Size (optional)>"
        parser.verify_num_parameters(0, 2, usage)
        @proc_text = ''
        @building_generic_conversion = true
        @converted_type = nil
        @converted_bit_size = nil
        if params[0]
          @converted_type = params[0].upcase.intern
          raise parser.error("Invalid converted_type: #{@converted_type}.") unless [:INT, :UINT, :FLOAT, :STRING, :BLOCK].include? @converted_type
        end
        @converted_bit_size = Integer(params[1]) if params[1]

      # Define a set of limits for the current telemetry item
      when 'LIMITS'
        process_limits(parser, keyword, params)

      # Define a response class that will be called when the limits state of the
      # current item changes.
      when 'LIMITS_RESPONSE'
        process_limits_response(parser, keyword, params)

      # Define a printf style formatting string for the current telemetry item
      when 'FORMAT_STRING'
        process_format_string(parser, keyword, params)

      # Define the units of the current telemetry item
      when 'UNITS'
        usage = "UNITS <FULL UNITS NAME> <ABBREVIATED UNITS NAME>"
        parser.verify_num_parameters(2, 2, usage)
        @current_item.units_full = params[0]
        @current_item.units = params[1]

      # Update the description for the current telemetry item
      when 'DESCRIPTION'
        usage = "DESCRIPTION <DESCRIPTION>"
        parser.verify_num_parameters(1, 1, usage)
        @current_item.description = params[0]

      # Mark the current command parameter as required.
      # This means it must be given a value and not just use its default.
      when 'REQUIRED'
        usage = "REQUIRED"
        parser.verify_num_parameters(0, 0, usage)
        if @current_cmd_or_tlm == 'Command'
          @current_item.required = true
        else
          raise parser.error("#{keyword} only applies to command parameters")
        end

      # Update the mimimum value for the current command parameter
      when 'MINIMUM_VALUE'
        if @current_cmd_or_tlm == 'Telemetry'
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "MINIMUM_VALUE <MINIMUM VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        @current_item.range =
          Range.new(ConfigParser.handle_defined_constants(
            params[0].convert_to_value), @current_item.range.end)

      # Update the maximum value for the current command parameter
      when 'MAXIMUM_VALUE'
        if @current_cmd_or_tlm == 'Telemetry'
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "MAXIMUM_VALUE <MAXIMUM VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        @current_item.range =
          Range.new(@current_item.range.begin,
                    ConfigParser.handle_defined_constants(params[0].convert_to_value))

      # Update the default value for the current command parameter
      when 'DEFAULT_VALUE'
        if @current_cmd_or_tlm == 'Telemetry'
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "DEFAULT_VALUE <DEFAULT VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        if ((@current_item.data_type == :STRING) ||
            (@current_item.data_type == :BLOCK))
          @current_item.default = params[0]
        else
          @current_item.default =
            ConfigParser.handle_defined_constants(params[0].convert_to_value)
        end

      # Update the overflow type for the current command parameter
      when 'OVERFLOW'
        usage = "OVERFLOW <OVERFLOW VALUE - ERROR, ERROR_ALLOW_HEX, TRUNCATE, or SATURATE>"
        parser.verify_num_parameters(1, 1, usage)
        @current_item.overflow = params[0].to_s.upcase.intern

      end
    end

    ####################################################
    # The following methods process a particular keyword

    def process_macro_append_start(parser, keyword, params)
      @macro_append.building = true

      usage = '#{keyword} <FIRST INDEX> <LAST INDEX> [NAME FORMAT]'
      parser.verify_num_parameters(2, 3, usage)

      # Store the params
      first_index = params[0].to_i
      last_index  = params[1].to_i
      @macro_append.indices = [first_index, last_index].sort
      @macro_append.indices = (@macro_append.indices[0]..@macro_append.indices[1]).to_a
      @macro_append.indices.reverse! if first_index > last_index
      @macro_append.format  = params[2] ? params[2] : '%s%d'
      spos = @macro_append.format.index(/%\d*s/)
      dpos = @macro_append.format.index(/%\d*d/)
      raise parser.error("Invalid NAME FORMAT (#{@macro_append.format}) for MACRO_APPEND_START", usage) unless spos and dpos
      if spos < dpos
        @macro_append.format_order = 'sd'
      else
        @macro_append.format_order = 'ds'
      end
    end

    def process_macro_append_end(parser, keyword)
      update_cache = false
      finish_item()
      parser.verify_num_parameters(0, 0, keyword)
      raise parser.error("Missing MACRO_APPEND_START before this config.line.", keyword) unless @macro_append.building
      raise parser.error("No items appended in MACRO_APPEND list", keyword) unless @macro_append.list.length > 0

      # Get first index, remove from array
      first = @macro_append.indices.shift

      # Rename the items in the list using the first index
      items = @current_packet.items
      @macro_append.list.each do |name|
        item = items[name]
        items.delete name
        if @macro_append.format_order == 'sd'
          first_name = sprintf(@macro_append.format, name, first)
        else
          first_name = sprintf(@macro_append.format, first, name)
        end
        item.name = first_name
        items[first_name] = item
      end

      # Append multiple copies of the items in the list
      @macro_append.indices.each do |index|
        @macro_append.list.each do |name|
          if @macro_append.format_order == 'sd'
            first_name = sprintf(@macro_append.format, name, first)
            this_name = sprintf(@macro_append.format, name, index)
          else
            first_name = sprintf(@macro_append.format, first, name)
            this_name = sprintf(@macro_append.format, index, name)
          end
          first_item = items[first_name]
          format_string = nil
          format_string = first_item.format_string if first_item.format_string
          this_item = @current_packet.append_item(this_name,
                                                  first_item.bit_size,
                                                  first_item.data_type,
                                                  first_item.array_size,
                                                  first_item.endianness,
                                                  first_item.overflow,
                                                  format_string,
                                                  first_item.read_conversion,
                                                  first_item.write_conversion,
                                                  first_item.id_value)
          this_item.states = first_item.states if first_item.states
          this_item.description = first_item.description if first_item.description
          this_item.units_full = first_item.units_full if first_item.units_full
          this_item.units = first_item.units if first_item.units
          this_item.default = first_item.default
          this_item.range = first_item.range if first_item.range
          this_item.required = first_item.required
          this_item.hazardous = first_item.hazardous
          if first_item.state_colors
            this_item.state_colors = first_item.state_colors
            update_cache = true
          end
          if first_item.limits
            this_item.limits = first_item.limits
            update_cache = true
          end
        end
      end
      @current_packet.update_limits_items_cache if update_cache

      @macro_append.building = false
      @macro_append.indices = []
      @macro_append.list = []
    end

    def process_state(parser, keyword, params)
      if @current_cmd_or_tlm == 'Command'
        usage = "#{keyword} <STATE NAME> <STATE VALUE> <HAZARDOUS (Optional)> <Hazardous Description (Optional)>"
        parser.verify_num_parameters(2, 4, usage)
      else
        usage = "#{keyword} <STATE NAME> <STATE VALUE> <COLOR: GREEN/YELLOW/RED (Optional)>"
        parser.verify_num_parameters(2, 3, usage)
      end
      @current_item.states ||= {}
      if @current_item.states[params[0].upcase]
        msg = "Duplicate state defined on line #{parser.line_number}: #{parser.line}"
        Logger.instance.warn(msg)
        @warnings << msg
      end
      if @current_item.data_type == :STRING or @current_item.data_type == :BLOCK
        @current_item.states[params[0].upcase] = params[1]
      else
        @current_item.states[params[0].upcase] = params[1].convert_to_value
      end
      if params[2]
        if @current_cmd_or_tlm == 'Command'
          if params[2].upcase == 'HAZARDOUS'
            @current_item.hazardous ||= {}
            if params[3]
              @current_item.hazardous[params[0].upcase] = params[3]
            else
              @current_item.hazardous[params[0].upcase] = ""
            end
          else
            raise parser.error("HAZARDOUS expected as third parameter for this line.", usage)
          end
        else
          if params[2]
            color = params[2].upcase.to_sym
            unless PacketItem::STATE_COLORS.include? color
              raise parser.error("Invalid state color #{color}. Must be one of #{PacketItem::STATE_COLORS.join(' ')}.", usage)
            end
            @current_item.limits ||= Limits.new
            @current_item.limits.enabled = true
            @current_item.state_colors ||= {}
            @current_item.state_colors[params[0].upcase] = color
            @current_packet.update_limits_items_cache
          end
        end
      end
    end

    def process_limits(parser, keyword, params)
      if @current_cmd_or_tlm == 'Command'
        raise parser.error("#{keyword} only applies to telemetry items")
      end
      usage = "#{keyword} <LIMITS SET> <PERSISTENCE> <ENABLED/DISABLED> <RED LOW LIMIT> <YELLOW LOW LIMIT> <YELLOW HIGH LIMIT> <RED HIGH LIMIT> <GREEN LOW LIMIT (Optional)> <GREEN HIGH LIMIT (Optional)>"
      parser.verify_num_parameters(7, 9, usage)

      begin
        persistence = Integer(params[1])
        red_low = Float(params[3])
        yellow_low = Float(params[4])
        yellow_high = Float(params[5])
        red_high = Float(params[6])
      rescue
        raise parser.error("Invalid persistence or limits values. Ensure persistence is an integer. Limits can be integers or floats.", usage)
      end

      enabled = params[2].upcase
      if enabled != 'ENABLED' and enabled != 'DISABLED'
        raise parser.error("Initial state must be ENABLED or DISABLED.", usage)
      end

      # Verify valid limits are specified
      if (red_low > yellow_low) or (yellow_low >= yellow_high) or (yellow_high > red_high)
        raise parser.error("Invalid limits specified. Ensure yellow limits are within red limits.", usage)
      end
      if params.length != 7
        begin
          green_low = Float(params[7])
          green_high = Float(params[8])
        rescue
          raise parser.error("Invalid green limits values. Limits can be integers or floats.", usage)
        end

        if (yellow_low > green_low) or (green_low >= green_high) or (green_high > yellow_high)
          raise parser.error("Invalid limits specified. Ensure green limits are within yellow limits.", usage)
        end
      end

      limits_set = params[0].upcase.to_sym
      @limits_sets << limits_set
      @limits_sets.uniq!
      # Initialize the limits values. Values must be initialized with a :DEFAULT key
      if !@current_item.limits.values
        if limits_set == :DEFAULT
          @current_item.limits.values = {:DEFAULT => []}
        else
          raise parser.error("DEFAULT limits must be defined for #{@current_packet.target_name} #{@current_packet.packet_name} #{@current_item.name} before setting limits set #{limits_set}")
        end
      end
      if limits_set != :DEFAULT
        msg = nil
        if (enabled == 'ENABLED' and @current_item.limits.enabled != true) or (enabled != 'ENABLED' and @current_item.limits.enabled != false)
          msg = "#{@current_cmd_or_tlm} Item #{@current_target_name} #{@current_packet_name} #{@current_item.name} #{limits_set} limits enable setting conflict with DEFAULT"
        end
        if @current_item.limits.persistence_setting != persistence
          msg = "#{@current_cmd_or_tlm} Item #{@current_target_name} #{@current_packet_name} #{@current_item.name} #{limits_set} limits persistence setting conflict with DEFAULT"
        end
        if msg
          Logger.instance.warn msg
          @warnings << msg
        end
      end
      @current_item.limits.enabled = true if enabled == 'ENABLED'
      values = @current_item.limits.values
      if params.length == 7
        values[limits_set] = [red_low, yellow_low, yellow_high, red_high]
      else
        values[limits_set] = [red_low, yellow_low, yellow_high, red_high, green_low, green_high]
      end
      @current_item.limits.values = values
      @current_item.limits.persistence_setting = persistence
      @current_item.limits.persistence_count   = 0
      @current_packet.update_limits_items_cache
    end

    def process_limits_response(parser, keyword, params)
      if @current_cmd_or_tlm == 'Command'
        raise parser.error("#{keyword} only applies to telemetry items")
      end
      usage = "#{keyword} <RESPONSE CLASS FILENAME> <RESPONSE SPECIFIC OPTIONS>"
      parser.verify_num_parameters(1, nil, usage)

      begin
        # require should be performed in target.txt
        klass = params[0].filename_to_class_name.to_class
        raise parser.error("#{params[0].filename_to_class_name} class not found. Did you require the file in target.txt?", usage) unless klass
        if params[1]
          @current_item.limits.response = klass.new(*params[1..(params.length - 1)])
        else
          @current_item.limits.response = klass.new
        end
      rescue Exception => err
        raise parser.error(err, usage)
      end
    end

    def process_processor(parser, keyword, params)
      if @current_cmd_or_tlm == 'Command'
        raise parser.error("#{keyword} only applies to telemetry packets")
      end
      usage = "#{keyword} <PROCESSOR NAME> <PROCESSOR CLASS FILENAME> <PROCESSOR SPECIFIC OPTIONS>"
      parser.verify_num_parameters(2, nil, usage)

      begin
        # require should be performed in target.txt
        klass = params[1].filename_to_class_name.to_class
        raise parser.error("#{params[1].filename_to_class_name} class not found. Did you require the file in target.txt?", usage) unless klass
        if params[2]
          processor = klass.new(*params[2..(params.length - 1)])
        else
          processor = klass.new
        end
        raise ArgumentError, "processor must be a Cosmos::Processor but is a #{processor.class}" unless Cosmos::Processor === processor
        processor.name = params[0]
        @current_packet.processors[params[0].to_s.upcase] = processor
      rescue Exception => err
        raise parser.error(err, usage)
      end
    end

    def process_format_string(parser, keyword, params)
      usage = "#{keyword} <PRINTF STYLE STRING>"
      parser.verify_num_parameters(1, 1, usage)
      @current_item.format_string = params[0]
      unless @current_item.read_conversion
        # Check format string as long as a read conversion has not been defined
        begin
          case @current_item.data_type
          when :INT, :UINT
            sprintf(@current_item.format_string, 0)
          when :FLOAT
            sprintf(@current_item.format_string, 0.0)
          when :STRING, :BLOCK
            sprintf(@current_item.format_string, 'Hello')
          else
            # Nothing to do
          end
        rescue Exception
          raise parser.error("Invalid #{keyword} specified for type #{@current_item.data_type}: #{params[0]}", usage)
        end
      end
    end

    def process_packet(parser, keyword, params, target_name)
      finish_packet()

      usage = "#{keyword} <TARGET NAME> <PACKET NAME> <ENDIANNESS: BIG_ENDIAN/LITTLE_ENDIAN> <DESCRIPTION (Optional)>"
      parser.verify_num_parameters(3, 4, usage)
      target_name = params[0].to_s.upcase if target_name == 'SYSTEM'
      packet_name = params[1].to_s.upcase
      endianness = params[2].to_s.upcase.intern
      description = params[3].to_s
      if endianness != :BIG_ENDIAN and endianness != :LITTLE_ENDIAN
        raise parser.error("Invalid endianness #{params[2]}. Must be BIG_ENDIAN or LITTLE_ENDIAN.", usage)
      end

      @current_target_name = target_name
      @current_packet_name = packet_name
      @current_cmd_or_tlm = keyword.capitalize

      # Be sure there is not already a packet by this name
      if @current_cmd_or_tlm == 'Command'
        if @commands[@current_target_name]
          if @commands[@current_target_name][@current_packet_name]
            msg = "#{@current_cmd_or_tlm} Packet #{@current_target_name} #{@current_packet_name} redefined."
            Logger.instance.warn msg
            @warnings << msg
          end
        end
      else
        if @telemetry[@current_target_name]
          if @telemetry[@current_target_name][@current_packet_name]
            msg = "#{@current_cmd_or_tlm} Packet #{@current_target_name} #{@current_packet_name} redefined."
            Logger.instance.warn msg
            @warnings << msg
          end
        end
      end

      @current_packet = Packet.new(@current_target_name, @current_packet_name, endianness, description)

      # Add received time packet items
      if @current_cmd_or_tlm == 'Telemetry'
        item = @current_packet.define_item('RECEIVED_TIMESECONDS', 0, 0, :DERIVED, nil, @current_packet.default_endianness, :ERROR, '%0.6f', ReceivedTimeSecondsConversion.new)
        item.description = 'COSMOS Received Time (UTC, Floating point, Unix epoch)'
        item = @current_packet.define_item('RECEIVED_TIMEFORMATTED', 0, 0, :DERIVED, nil, @current_packet.default_endianness, :ERROR, nil, ReceivedTimeFormattedConversion.new)
        item.description = 'COSMOS Received Time (Local time zone, Formatted string)'
        item = @current_packet.define_item('RECEIVED_COUNT', 0, 0, :DERIVED, nil, @current_packet.default_endianness, :ERROR, nil, ReceivedCountConversion.new)
        item.description = 'COSMOS packet received count'

        unless @telemetry[@current_target_name]
          @telemetry[@current_target_name] = {}
          @latest_data[@current_target_name] = {}
        end
      else
        @commands[@current_target_name] ||= {}
      end
    end

    # Add current packet into hash if it exists
    def finish_packet
      finish_item()
      if @current_packet
        # Review bit offset to look for overlapping definitions
        # This will allow gaps in the packet, but not allow the same bits to be
        # used for multiple variables.
        expected_next_offset = nil
        previous_item = nil
        @current_packet.sorted_items.each do |item|
          if expected_next_offset and item.bit_offset < expected_next_offset
            msg = "Bit definition overlap at bit offset #{item.bit_offset} for #{@current_cmd_or_tlm} packet #{@current_target_name} #{@current_packet_name} items #{item.name} and #{previous_item.name}"
            Logger.instance.warn(msg)
            @warnings << msg
          end
          if item.array_size
            if item.array_size > 0
              expected_next_offset = item.bit_offset + item.array_size
            else
              expected_next_offset = item.array_size
            end
          else
            expected_next_offset = nil
            if item.bit_offset > 0
              # Handle little-endian bit fields
              byte_aligned = ((item.bit_offset % 8) == 0)
              if item.endianness == :LITTLE_ENDIAN and (item.data_type == :INT or item.data_type == :UINT) and !(byte_aligned and (item.bit_size == 8 or item.bit_size == 16 or item.bit_size == 32 or item.bit_size == 64))
                # Bitoffset always refers to the most significant bit of a bitfield
                bits_remaining_in_last_byte = 8 - (item.bit_offset % 8)
                if item.bit_size > bits_remaining_in_last_byte
                  expected_next_offset = item.bit_offset + bits_remaining_in_last_byte
                end
              end
            end
            unless expected_next_offset
              if item.bit_size > 0
                expected_next_offset = item.bit_offset + item.bit_size
              else
                expected_next_offset = item.bit_size
              end
            end
          end
          previous_item = item

          # Check command default and range data types if no write conversion is present
          item.check_default_and_range_data_types if @current_cmd_or_tlm == 'Command'
        end

        # commit packet to memory
        if @current_cmd_or_tlm == 'Command'
          @commands[@current_target_name][@current_packet_name] = @current_packet
        else
          @telemetry[@current_target_name][@current_packet_name] = @current_packet
        end
        @current_packet = nil
        @current_item = nil
      end
    end

    def start_item(parser)
      finish_item()
      @current_item = PacketItemParser.parse(parser, @current_packet, @current_cmd_or_tlm)

      if parser.keyword.include?('APPEND') && @macro_append.building
        @macro_append.list << parser.parameters[0].upcase
      end
    end

    # Finish updating packet item
    def finish_item
      if @current_item
        @current_packet.set_item(@current_item)
        if @current_cmd_or_tlm == 'Telemetry'
          target_latest_data = @latest_data[@current_target_name]
          target_latest_data[@current_item.name] ||= []
          latest_data_packets = target_latest_data[@current_item.name]
          latest_data_packets << @current_packet unless latest_data_packets.include?(@current_packet)
        end
        @current_item = nil
      end
    end

  end # class PacketConfig

end # module Cosmos
