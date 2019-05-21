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
require 'cosmos/packets/parsers/packet_parser'
require 'cosmos/packets/parsers/packet_item_parser'
require 'cosmos/packets/parsers/macro_parser'
require 'cosmos/packets/parsers/limits_parser'
require 'cosmos/packets/parsers/limits_response_parser'
require 'cosmos/packets/parsers/state_parser'
require 'cosmos/packets/parsers/format_string_parser'
require 'cosmos/packets/parsers/processor_parser'
require 'cosmos/packets/parsers/xtce_parser'
require 'cosmos/packets/parsers/xtce_converter'
require 'cosmos/conversions'
require 'cosmos/processors'
require 'nokogiri'
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

    # @return [Hash<String>=>Hash<Array>=>Packet] Hash keyed by target name
    # that returns a hash keyed by an array of id values.  The id values resolve to the packet
    # defined by that identification.  Command version
    attr_reader :cmd_id_value_hash

    # @return [Hash<String>=>Hash<Array>=>Packet] Hash keyed by target name
    # that returns a hash keyed by an array of id values.  The id values resolve to the packet
    # defined by that identification.  Telemetry version
    attr_reader :tlm_id_value_hash

    COMMAND = "Command"
    TELEMETRY = "Telemetry"

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
      @cmd_id_value_hash = {}
      @tlm_id_value_hash = {}

      # Create unknown packets
      @commands['UNKNOWN'] = {}
      @commands['UNKNOWN']['UNKNOWN'] = Packet.new('UNKNOWN', 'UNKNOWN', :BIG_ENDIAN)
      @telemetry['UNKNOWN'] = {}
      @telemetry['UNKNOWN']['UNKNOWN'] = Packet.new('UNKNOWN', 'UNKNOWN', :BIG_ENDIAN)

      reset_processing_variables()
    end

    #########################################################################
    # The following methods process a command or telemetry packet config file
    #########################################################################

    # Processes a COSMOS configuration file and uses the keywords to build up
    # knowledge of the commands, telemetry, and limits groups.
    #
    # @param filename [String] The name of the configuration file
    # @param process_target_name [String] The target name. Pass nil when parsing
    #   an xtce file to automatically determine the target name.
    def process_file(filename, process_target_name)
      # Handle .xtce files
      if File.extname(filename).to_s.downcase == ".xtce"
        XtceParser.process(@commands, @telemetry, @warnings, filename, process_target_name)
        return
      end

      # Partial files are included into another file and thus aren't directly processed
      return if File.basename(filename)[0] == '_' # Partials start with underscore

      @converted_type = nil
      @converted_bit_size = nil
      @proc_text = ''
      @building_generic_conversion = false

      process_target_name = process_target_name.upcase
      parser = ConfigParser.new("http://cosmosrb.com/docs/cmdtlm")
      parser.instance_variable_set(:@target_name, process_target_name)
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
          when 'COMMAND'
            finish_packet()
            @current_packet = PacketParser.parse_command(parser, process_target_name, @commands, @warnings)
            @current_cmd_or_tlm = COMMAND

          when 'TELEMETRY'
            finish_packet()
            @current_packet = PacketParser.parse_telemetry(parser, process_target_name, @telemetry, @latest_data, @warnings)
            @current_cmd_or_tlm = TELEMETRY

          # Select an existing packet for editing
          when 'SELECT_COMMAND', 'SELECT_TELEMETRY'
            usage = "#{keyword} <TARGET NAME> <PACKET NAME>"
            finish_packet()
            parser.verify_num_parameters(2, 2, usage)
            target_name = process_target_name
            target_name = params[0].upcase if target_name == 'SYSTEM'
            packet_name = params[1].upcase

            @current_packet = nil
            if keyword.include?('COMMAND')
              @current_cmd_or_tlm = COMMAND
              if @commands[target_name]
                @current_packet = @commands[target_name][packet_name]
              end
            else
              @current_cmd_or_tlm = TELEMETRY
              if @telemetry[target_name]
                @current_packet = @telemetry[target_name][packet_name]
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

    # Convert the PacketConfig back to COSMOS configuration files for each target
    def to_config(output_dir)
      FileUtils.mkdir_p(output_dir)

      @telemetry.each do |target_name, packets|
        next if target_name == 'UNKNOWN'
        FileUtils.mkdir_p(File.join(output_dir, target_name, 'cmd_tlm'))
        filename = File.join(output_dir, target_name, 'cmd_tlm', target_name.downcase + '_tlm.txt')
        begin
          File.delete(filename)
        rescue
          # Doesn't exist
        end
        packets.each do |packet_name, packet|
          File.open(filename, 'a') do |file|
            file.puts packet.to_config(:TELEMETRY)
            file.puts ""
          end
        end
      end

      @commands.each do |target_name, packets|
        next if target_name == 'UNKNOWN'
        FileUtils.mkdir_p(File.join(output_dir, target_name, 'cmd_tlm'))
        filename = File.join(output_dir, target_name, 'cmd_tlm', target_name.downcase + '_cmd.txt')
        begin
          File.delete(filename)
        rescue
          # Doesn't exist
        end
        packets.each do |packet_name, packet|
          File.open(filename, 'a') do |file|
            file.puts packet.to_config(:COMMAND)
            file.puts ""
          end
        end
      end

      # Put limits groups into SYSTEM target
      if @limits_groups.length > 0
        FileUtils.mkdir_p(File.join(output_dir, 'SYSTEM', 'cmd_tlm'))
        filename = File.join(output_dir, 'SYSTEM', 'cmd_tlm', 'limits_groups.txt')
        File.open(filename, 'w') do |file|
          @limits_groups.each do |limits_group_name, limits_group_items|
            file.puts "LIMITS_GROUP #{limits_group_name.to_s.quote_if_necessary}"
            limits_group_items.each do |target_name, packet_name, item_name|
              file.puts "  LIMITS_GROUP_ITEM #{target_name.to_s.quote_if_necessary} #{packet_name.to_s.quote_if_necessary} #{item_name.to_s.quote_if_necessary}"
            end
            file.puts ""
          end
        end
      end
    end # def to_config

    def to_xtce(output_dir)
      XtceConverter.convert(@commands, @telemetry, output_dir)
    end

    # Add current packet into hash if it exists
    def finish_packet()
      finish_item()
      if @current_packet
        @warnings += @current_packet.check_bit_offsets
        if @current_cmd_or_tlm == COMMAND
          PacketParser.check_item_data_types(@current_packet)
          @commands[@current_packet.target_name][@current_packet.packet_name] = @current_packet
          hash = @cmd_id_value_hash[@current_packet.target_name]
          hash = {} unless hash
          @cmd_id_value_hash[@current_packet.target_name] = hash
          update_id_value_hash(hash)
        else
          @telemetry[@current_packet.target_name][@current_packet.packet_name] = @current_packet
          hash = @tlm_id_value_hash[@current_packet.target_name]
          hash = {} unless hash
          @tlm_id_value_hash[@current_packet.target_name] = hash
          update_id_value_hash(hash)
        end
        @current_packet = nil
        @current_item = nil
      end
    end

    protected

    def update_id_value_hash(hash)
      if @current_packet.id_items.length > 0
        key = []
        @current_packet.id_items.each do |item|
          key << item.id_value
        end
        hash[key] = @current_packet
      else
        hash['CATCHALL'.freeze] = @current_packet
      end
    end

    def reset_processing_variables
      @current_cmd_or_tlm = nil
      @current_packet = nil
      @current_item = nil
      @current_limits_group = nil
    end

    def process_current_packet(parser, keyword, params)
      case keyword

      # Select an item in the current telemetry packet for editing
      when 'SELECT_PARAMETER', 'SELECT_ITEM'
        if (@current_cmd_or_tlm == COMMAND) && (keyword.split('_')[1] == 'ITEM')
          raise parser.error("SELECT_ITEM only applies to telemetry packets")
        end
        if (@current_cmd_or_tlm == TELEMETRY) && (keyword.split('_')[1] == 'PARAMETER')
          raise parser.error("SELECT_PARAMETER only applies to command packets")
        end
        usage = "#{keyword} <#{keyword.split('_')[1]} NAME>"
        finish_item()
        parser.verify_num_parameters(1, 1, usage)
        begin
          @current_item = @current_packet.get_item(params[0])
        rescue # Rescue the default execption to provide a nicer error message
          raise parser.error("#{params[0]} not found in #{@current_cmd_or_tlm.downcase} packet #{@current_packet.target_name} #{@current_packet.packet_name}", usage)
        end

      # Start a new telemetry item in the current packet
      when 'ITEM', 'PARAMETER', 'ID_ITEM', 'ID_PARAMETER', 'ARRAY_ITEM', 'ARRAY_PARAMETER', 'APPEND_ITEM', 'APPEND_PARAMETER', 'APPEND_ID_ITEM', 'APPEND_ID_PARAMETER', 'APPEND_ARRAY_ITEM', 'APPEND_ARRAY_PARAMETER'
        start_item(parser)

      # Start the creation of a macro-expanded list of items
      # This simulates an array of structures of multiple items in the packet by repeating
      # each item in the list multiple times with a different "index" added to the name.
      when 'MACRO_APPEND_START'
        Logger.warn "MACRO_APPEND_START/END is deprecated. Please use new ERB macro syntax."
        MacroParser.start(parser)

      # End the creation of a macro-expanded list of items
      when 'MACRO_APPEND_END'
        finish_item()
        MacroParser.end(parser, @current_packet)

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
        ProcessorParser.parse(parser, @current_packet, @current_cmd_or_tlm)

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
        StateParser.parse(parser, @current_packet, @current_cmd_or_tlm, @current_item, @warnings)

      # Apply a conversion to the current item after it is read to or
      # written from the packet
      when 'READ_CONVERSION', 'WRITE_CONVERSION'
        usage = "#{keyword} <conversion class filename> <custom parameters> ..."
        parser.verify_num_parameters(1, nil, usage)
        begin
          # require should be performed in target.txt
          klass = params[0].filename_to_class_name.to_class
          raise parser.error("#{params[0].filename_to_class_name} class not found. Did you require the file in target.txt?", usage) unless klass
          conversion = klass.new(*params[1..(params.length - 1)])
          @current_item.send("#{keyword.downcase}=".to_sym, conversion)
          if klass != ProcessorConversion and (conversion.converted_type.nil? or conversion.converted_bit_size.nil?)
            msg = "Read Conversion #{params[0].filename_to_class_name} on item #{@current_item.name} does not specify converted type or bit size. Will not be supported by DART"
            @warnings << msg
            Logger.instance.warn @warnings[-1]
          end
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
        if @converted_type.nil? or @converted_bit_size.nil?
          msg = "Generic Conversion on item #{@current_item.name} does not specify converted type or bit size. Will not be supported by DART"
          @warnings << msg
          Logger.instance.warn @warnings[-1]
        end

      # Define a set of limits for the current telemetry item
      when 'LIMITS'
        @limits_sets << LimitsParser.parse(parser, @current_packet, @current_cmd_or_tlm, @current_item, @warnings)
        @limits_sets.uniq!

      # Define a response class that will be called when the limits state of the
      # current item changes.
      when 'LIMITS_RESPONSE'
        LimitsResponseParser.parse(parser, @current_item, @current_cmd_or_tlm)

      # Define a printf style formatting string for the current telemetry item
      when 'FORMAT_STRING'
        FormatStringParser.parse(parser, @current_item)

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
        if @current_cmd_or_tlm == COMMAND
          @current_item.required = true
        else
          raise parser.error("#{keyword} only applies to command parameters")
        end

      # Update the mimimum value for the current command parameter
      when 'MINIMUM_VALUE'
        if @current_cmd_or_tlm == TELEMETRY
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "MINIMUM_VALUE <MINIMUM VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        min = ConfigParser.handle_defined_constants(
          params[0].convert_to_value, @current_item.data_type, @current_item.bit_size)
        @current_item.range = Range.new(min, @current_item.range.end)

      # Update the maximum value for the current command parameter
      when 'MAXIMUM_VALUE'
        if @current_cmd_or_tlm == TELEMETRY
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "MAXIMUM_VALUE <MAXIMUM VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        max = ConfigParser.handle_defined_constants(
          params[0].convert_to_value, @current_item.data_type, @current_item.bit_size)
        @current_item.range = Range.new(@current_item.range.begin, max)

      # Update the default value for the current command parameter
      when 'DEFAULT_VALUE'
        if @current_cmd_or_tlm == TELEMETRY
          raise parser.error("#{keyword} only applies to command parameters")
        end
        usage = "DEFAULT_VALUE <DEFAULT VALUE>"
        parser.verify_num_parameters(1, 1, usage)
        if ((@current_item.data_type == :STRING) ||
            (@current_item.data_type == :BLOCK))
          @current_item.default = params[0]
        else
          @current_item.default = ConfigParser.handle_defined_constants(
            params[0].convert_to_value, @current_item.data_type, @current_item.bit_size)
        end

      # Update the overflow type for the current command parameter
      when 'OVERFLOW'
        usage = "OVERFLOW <OVERFLOW VALUE - ERROR, ERROR_ALLOW_HEX, TRUNCATE, or SATURATE>"
        parser.verify_num_parameters(1, 1, usage)
        @current_item.overflow = params[0].to_s.upcase.intern

      end
    end

    def start_item(parser)
      finish_item()
      @current_item = PacketItemParser.parse(parser, @current_packet, @current_cmd_or_tlm, @warnings)
      MacroParser.new_item()
    end

    # Finish updating packet item
    def finish_item
      if @current_item
        @current_packet.set_item(@current_item)
        if @current_cmd_or_tlm == TELEMETRY
          target_latest_data = @latest_data[@current_packet.target_name]
          target_latest_data[@current_item.name] ||= []
          latest_data_packets = target_latest_data[@current_item.name]
          latest_data_packets << @current_packet unless latest_data_packets.include?(@current_packet)
        end
        @current_item = nil
      end
    end
  end
end
