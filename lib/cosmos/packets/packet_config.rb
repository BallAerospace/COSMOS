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

      # Create unknown packets
      @commands['UNKNOWN']
      @commands['UNKNOWN'] = {}
      @commands['UNKNOWN']['UNKNOWN'] = Packet.new('UNKNOWN', 'UNKNOWN', :BIG_ENDIAN)
      @telemetry['UNKNOWN']
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
    # @param target_name [String] The target name
    def process_file(filename, process_target_name)
      # Handle .xtce files
      if File.extname(filename).to_s.downcase == ".xtce"
        process_xtce(filename, process_target_name)
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
      parser.parse_file(filename) do |keyword, params|

        if @building_generic_conversion
          case keyword
          # Complete a generic conversion
          when 'GENERIC_READ_CONVERSION_END', 'GENERIC_WRITE_CONVERSION_END', 'CONSTRAINT_END'
            parser.verify_num_parameters(0, 0, keyword)
            @current_item.read_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "READ"
            @current_item.write_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "WRITE"
            @current_item.constraint =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "CONSTRAINT"
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

    # Read in a target definition from a .xtce file
    def process_xtce(filename, override_target_name = nil)
      doc = File.open(filename) { |f| Nokogiri::XML(f, nil, nil, Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NOBLANKS) }
      xtce_process_element(doc.root, 0)
      @current_target_name = override_target_name if override_target_name
      doc.root.children.each do |child|
        xtce_recurse_element(child, 1) do |element, depth|
          xtce_process_element(element, depth)
        end
      end
      finish_packet()

      # Remove abstract
      @commands[@current_target_name].delete_if {|packet_name, packet| packet.abstract}
      @telemetry[@current_target_name].delete_if {|packet_name, packet| packet.abstract}

      # Reverse order of packets for the target so ids work correctly
      reverse_packet_order(@current_target_name, @commands)
      reverse_packet_order(@current_target_name, @telemetry)

      reset_processing_variables()
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

    # Convert the PacketConfig into a .xtce file for each target
    def to_xtce(output_dir)
      FileUtils.mkdir_p(output_dir)

      # Build target list
      targets = []
      @telemetry.each { |target_name, packets| targets << target_name }
      @commands.each { |target_name, packets| targets << target_name }
      targets.uniq!

      targets.each do |target_name|
        next if target_name == 'UNKNOWN'

        # Reverse order of packets for the target so things are expected (reverse) order for xtce
        reverse_packet_order(target_name, @commands)
        reverse_packet_order(target_name, @telemetry)

        FileUtils.mkdir_p(File.join(output_dir, target_name, 'cmd_tlm'))
        filename = File.join(output_dir, target_name, 'cmd_tlm', target_name.downcase + '.xtce')
        begin
          File.delete(filename)
        rescue
          # Doesn't exist
        end

        # Gather an make unique all the packet items
        unique_items = {}
        @telemetry[target_name].each do |packet_name, packet|
          packet.sorted_items.each do |item|
            next if item.data_type == :DERIVED
            unique_items[item.name] ||= []
            unique_items[item.name] << item
          end
        end
        unique_items.each do |item_name, items|
          if items.length <= 1
            unique_items[item_name] = items[0]
            next
          end
          # TODO: need to make sure all the items in the array are exactly the same
          unique_items[item_name] = items[0]
        end

        # Gather and make unique all the command parameters
        unique_arguments = {}
        @commands[target_name].each do |packet_name, packet|
          packet.sorted_items.each do |item|
            next if item.data_type == :DERIVED
            unique_arguments[item.name] ||= []
            unique_arguments[item.name] << item
          end
        end
        unique_arguments.each do |item_name, items|
          if items.length <= 1
            unique_arguments[item_name] = items[0]
            next
          end
          # TODO: need to make sure all the items in the array are exactly the same
          unique_arguments[item_name] = items[0]
        end

        # Create the xtce file for this target
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml['xtce'].SpaceSystem("xmlns:xtce" => "http://www.omg.org/space/xtce",
            "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
            "name" => target_name,
            "xsi:schemaLocation" => "http://www.omg.org/space/xtce http://www.omg.org/spec/XTCE/20061101/06-11-06.xsd") do
            xml['xtce'].TelemetryMetaData do
              xml['xtce'].ParameterTypeSet do
                unique_items.each do |item_name, item|
                  item.to_xtce_type('Parameter', xml)
                end
              end

              xml['xtce'].ParameterSet do
                unique_items.each do |item_name, item|
                  item.to_xtce_item('Parameter', xml)
                end
              end

              xml['xtce'].ContainerSet do
                @telemetry[target_name].each do |packet_name, packet|
                  attrs = { :name => (packet_name + '_Base'), :abstract => "true" }
                  xml['xtce'].SequenceContainer(attrs) do
                    xml['xtce'].EntryList do
                      packed = packet.packed?
                      packet.sorted_items.each do |item|
                        next if item.data_type == :DERIVED
                        # TODO: Handle nonunique item names
                        if item.array_size
                          xml['xtce'].ArrayParameterRefEntry(:parameterRef => item.name) do
                            if !packed
                              if item.bit_offset >= 0
                                xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerStart') do
                                  xml['xtce'].FixedValue(item.bit_offset)
                                end
                              else
                                xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerEnd') do
                                  xml['xtce'].FixedValue(-item.bit_offset)
                                end
                              end
                            end
                            xml['xtce'].DimensionList do
                              xml['xtce'].Dimension do
                                xml['xtce'].StartingIndex do
                                  xml['xtce'].FixedValue(0)
                                end
                                xml['xtce'].EndingIndex do
                                  xml['xtce'].FixedValue((item.array_size / item.bit_size) - 1)
                                end
                              end
                            end
                          end
                        else
                          if packed
                            xml['xtce'].ParameterRefEntry(:parameterRef => item.name)
                          else
                            xml['xtce'].ParameterRefEntry(:parameterRef => item.name) do
                              if item.bit_offset >= 0
                                xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerStart') do
                                  xml['xtce'].FixedValue(item.bit_offset)
                                end
                              else
                                xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerEnd') do
                                  xml['xtce'].FixedValue(-item.bit_offset)
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end # Abstract SequenceContainer

                  attrs = { :name => packet_name }
                  attrs['shortDescription'] = packet.description if packet.description
                  xml['xtce'].SequenceContainer(attrs) do
                    xml['xtce'].EntryList
                    xml['xtce'].BaseContainer(:containerRef => (packet_name + '_Base')) do
                      if packet.id_items and packet.id_items.length > 0
                        xml['xtce'].RestrictionCriteria do
                          xml['xtce'].ComparisonList do
                            packet.id_items.each do |item|
                              xml['xtce'].Comparison(:parameterRef => item.name, :value => item.id_value)
                            end
                          end
                        end
                      end
                    end
                  end # Actual SequenceContainer

                end # @telemetry.each
              end # ContainerSet
            end # TelemetryMetaData

            xml['xtce'].CommandMetaData do
              xml['xtce'].ArgumentTypeSet do
                unique_arguments.each do |arg_name, arg|
                  arg.to_xtce_type('Argument', xml)
                end
              end
              xml['xtce'].MetaCommandSet do
                @commands[target_name].each do |packet_name, packet|
                  attrs = { :name => packet_name + "_Base", :abstract => "true" }
                  xml['xtce'].MetaCommand(attrs) do
                    xml['xtce'].ArgumentList do
                      packet.sorted_items.each do |item|
                        next if item.data_type == :DERIVED
                        item.to_xtce_item('Argument', xml)
                      end
                    end # ArgumentList
                    xml['xtce'].CommandContainer(:name => "#{target_name}_#{packet_name}_CommandContainer") do
                      xml['xtce'].EntryList do
                        packed = packet.packed?
                        packet.sorted_items.each do |item|
                          next if item.data_type == :DERIVED
                          if item.array_size
                            xml['xtce'].ArrayArgumentRefEntry(:parameterRef => item.name) do
                              if !packed
                                if item.bit_offset >= 0
                                  xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerStart') do
                                    xml['xtce'].FixedValue(item.bit_offset)
                                  end
                                else
                                  xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerEnd') do
                                    xml['xtce'].FixedValue(-item.bit_offset)
                                  end
                                end
                              end
                              xml['xtce'].DimensionList do
                                xml['xtce'].Dimension do
                                  xml['xtce'].StartingIndex do
                                    xml['xtce'].FixedValue(0)
                                  end
                                  xml['xtce'].EndingIndex do
                                    xml['xtce'].FixedValue((item.array_size / item.bit_size) - 1)
                                  end
                                end
                              end
                            end
                          else
                            if packed
                              xml['xtce'].ArgumentRefEntry(:argumentRef => item.name)
                            else
                              xml['xtce'].ArgumentRefEntry(:argumentRef => item.name) do
                                if item.bit_offset >= 0
                                  xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerStart') do
                                    xml['xtce'].FixedValue(item.bit_offset)
                                  end
                                else
                                  xml['xtce'].LocationInContainerInBits(:referenceLocation => 'containerEnd') do
                                    xml['xtce'].FixedValue(-item.bit_offset)
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end # Abstract MetaCommand

                  attrs = { :name => packet_name }
                  attrs['shortDescription'] = packet.description if packet.description
                  xml['xtce'].MetaCommand(attrs) do
                    xml['xtce'].BaseMetaCommand(:metaCommandRef => packet_name + "_Base") do
                      if packet.id_items and packet.id_items.length > 0
                        xml['xtce'].ArgumentAssignmentList do
                          packet.id_items.each do |item|
                            xml['xtce'].ArgumentAssignment(:argumentName => item.name, :argumentValue => item.id_value)
                          end
                        end # ArgumentAssignmentList
                      end
                    end # BaseMetaCommand
                  end # Actual MetaCommand
                end # @commands.each
              end # MetaCommandSet
            end # CommandMetaData
          end # SpaceSystem
        end # builder
        File.open(filename, 'w') do |file|
          file.puts builder.to_xml
        end
      end
    end

    protected

    def reset_processing_variables
      # Used during packet processing
      @current_cmd_or_tlm = nil
      @current_packet = nil
      @current_item = nil
      @current_limits_group = nil

      # Used for xtce processing
      @current_target_name = nil
      @current_type = nil
      @current_meta_command = nil
      @current_parameter = nil
      @current_argument = nil
      @parameter_types = {}
      @argument_types = {}
      @parameters = {}
      @arguments = {}
      @containers = {}
    end

    def reverse_packet_order(target_name, cmd_or_tlm_hash)
      packets = []
      names_to_remove = []
      cmd_or_tlm_hash[target_name].each do |packet_name, packet|
        packets << packet
        names_to_remove << packet_name
      end
      cmd_or_tlm_hash[target_name].length.times do |i|
        cmd_or_tlm_hash[target_name].delete(names_to_remove[i])
      end
      packets.reverse.each do |packet|
        cmd_or_tlm_hash[target_name][packet.packet_name] = packet
      end
    end

    XTCE_IGNORED_ELEMENTS = ['text', 'AliasSet', 'Alias', 'Header']

    def xtce_process_element(element, depth)
      if XTCE_IGNORED_ELEMENTS.include?(element.name)
        return false
      end

      case element.name
      when 'SpaceSystem'
        @current_target_name = element["name"].to_s.upcase

      when 'TelemetryMetaData'
        finish_packet()
        @current_cmd_or_tlm = TELEMETRY

      when 'CommandMetaData'
        finish_packet()
        @current_cmd_or_tlm = COMMAND

      when 'ParameterTypeSet', 'EnumerationList', 'ParameterSet', 'ContainerSet', 'EntryList', 'DefaultCalibrator', 'DefaultAlarm',
        'RestrictionCriteria', 'ComparisonList', 'MetaCommandSet', 'DefaultCalibrator', 'ArgumentTypeSet', 'ArgumentList', 'ArgumentAssignmentList',
        'LocationInContainerInBits'

        # Do Nothing

      when 'EnumeratedParameterType', 'EnumeratedArgumentType', 'IntegerParameterType', 'IntegerArgumentType', 'FloatParameterType', 'FloatArgumentType',
        'StringParameterType', 'StringArgumentType', 'BinaryParameterType', 'BinaryArgumentType'

        @current_type = OpenStruct.new
        @current_type.endianness = :BIG_ENDIAN
        element.attributes.each do |att_name, att|
          @current_type[att.name] = att.value
        end
        if element.name =~ /Argument/
          @argument_types[element["name"]] = @current_type
        else
          @parameter_types[element["name"]] = @current_type
        end

        case element.name
        when 'EnumeratedParameterType', 'EnumeratedArgumentType'
          @current_type.xtce_encoding = 'IntegerDataEncoding'
          @current_type.sizeInBits = 8 # This is undocumented but appears to be the design
        when 'IntegerParameterType', 'IntegerArgumentType'
          @current_type.xtce_encoding = 'IntegerDataEncoding'
          @current_type.sizeInBits = 32
        when 'FloatParameterType', 'FloatArgumentType'
          @current_type.xtce_encoding = 'FloatDataEncoding'
          @current_type.sizeInBits = 32
        when 'StringParameterType', 'StringArgumentType'
          @current_type.xtce_encoding = 'StringDataEncoding'
        when 'BinaryParameterType', 'BinaryArgumentType'
          @current_type.xtce_encoding = 'BinaryDataEncoding'
          @current_type.sizeInBits = 8 # This is undocumented but appears to be the design
        end

      when 'ArrayParameterType', 'ArrayArgumentType'
        @current_type = OpenStruct.new
        element.attributes.each do |att_name, att|
          @current_type[att.name] = att.value
        end
        if element.name =~ /Argument/
          @argument_types[element["name"]] = @current_type
        else
          @parameter_types[element["name"]] = @current_type
        end

      when 'ByteOrderList'
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'Byte'
            if element['byteSignificance'] and element['byteSignificance'].to_i == 0
              @current_type.endianness = :LITTLE_ENDIAN
            end
            false
          else
            true
          end
        end
        return false # Already recursed

      when "SizeInBits"
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'FixedValue'
            @current_type.sizeInBits = Integer(element.text)
            false
          else
            true
          end
        end
        return false # Already recursed

      when 'UnitSet'
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'Unit'
            @current_type.units ||= ''
            if @current_type.units.empty?
              @current_type.units << element.text.to_s
            else
              @current_type.units << ('/' + element.text.to_s)
            end
            @current_type.units << "^#{element['power']}" if element['power']
            @current_type.units_full ||= ''
            description = element['description'].to_s
            if description.empty?
              @current_type.units_full = @current_type.units
            else
              if @current_type.units_full.empty?
                @current_type.units_full << description
              else
                @current_type.units_full << ('/' + description)
              end
            end
          end
          true
        end
        return false # Already recursed

      when 'PolynomialCalibrator'
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'Term'
            index = Float(element['exponent']).to_i
            coeff = Float(element['coefficient'])
            @current_type.conversion ||= PolynomialConversion.new([])
            @current_type.conversion.coeffs[index] = coeff
            @current_type.conversion.coeffs.each_with_index do |value, index|
              @current_type.conversion.coeffs[index] = 0.0 if value.nil?
            end
          end
          true
        end
        return false # Already recursed

      when 'StaticAlarmRanges'
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'WarningRange'
            @current_type.limits ||= [0.0, 0.0, 0.0, 0.0]
            @current_type.limits[1] = Float(element['minInclusive']) if element['minInclusive']
            @current_type.limits[2] = Float(element['maxInclusive']) if element['maxInclusive']
          elsif element.name == 'CriticalRange'
            @current_type.limits ||= [0.0, 0.0, 0.0, 0.0]
            @current_type.limits[0] = Float(element['minInclusive']) if element['minInclusive']
            @current_type.limits[3] = Float(element['maxInclusive']) if element['maxInclusive']
          end
          true
        end
        return false # Already recursed

      when "ValidRange"
        @current_type.minInclusive = element['minInclusive']
        @current_type.maxInclusive = element['maxInclusive']

      when 'Enumeration'
        @current_type.states ||= {}
        @current_type.states[element['label']] = Integer(element['value'])

      when 'IntegerDataEncoding', 'FloatDataEncoding', 'StringDataEncoding', 'BinaryDataEncoding'
        @current_type.xtce_encoding = element.name
        element.attributes.each do |att_name, att|
          @current_type[att.name] = att.value
        end
        @current_type.sizeInBits = 8 unless element.attributes['sizeInBits']

      when 'Parameter'
        @current_parameter = OpenStruct.new
        element.attributes.each do |att_name, att|
          @current_parameter[att.name] = att.value
        end
        @parameters[element["name"]] = @current_parameter

      when 'Argument'
        @current_argument = OpenStruct.new
        element.attributes.each do |att_name, att|
          @current_argument[att.name] = att.value
        end
        @arguments[element["name"]] = @current_argument

      when 'ParameterProperties'
        element.attributes.each do |att_name, att|
          @current_parameter[att.name] = att.value
        end

      when "SequenceContainer"
        finish_packet()
        @current_packet = Packet.new(@current_target_name, element['name'], :BIG_ENDIAN, element['shortDescription'])
        @current_packet.abstract = ConfigParser.handle_true_false_nil(element['abstract'])
        @containers[element['name']] = @current_packet
        PacketParser.finish_create_telemetry(@current_packet, @telemetry, @latest_data, @warnings)

        # Need to check for a BaseContainer now because if we hit it later it will be too late
        xtce_handle_base_container('BaseContainer', element)

      when 'LongDescription'
        if @current_packet and !@current_packet.description
          @current_packet.description = element.text
        end

      when 'ParameterRefEntry', 'ArgumentRefEntry', 'ArrayParameterRefEntry', 'ArrayArgumentRefEntry'
        reference_location, bit_offset = xtce_handle_location_in_container_in_bits(element)

        array_type = nil
        array_bit_size = nil
        if element.name =~ /Parameter/
          # Look up the parameter and parameter type
          parameter = @parameters[element['parameterRef']]
          raise "parameterRef #{element['parameterRef']} not found" unless parameter
          parameter_type = @parameter_types[parameter.parameterTypeRef]
          raise "parameterTypeRef #{parameter.parameterTypeRef} not found" unless parameter_type
          if element.name == 'ArrayParameterRefEntry'
            array_type = parameter_type
            parameter_type = @parameter_types[array_type.arrayTypeRef]
            raise "arrayTypeRef #{parameter.arrayTypeRef} not found" unless parameter_type
          end
          refName = 'parameterRef'
          object = parameter
          type = parameter_type
        else
          # Look up the argument and argument type
          if element.name == 'ArrayArgumentRefEntry'
            # Requiring parameterRef for argument arrays appears to be a defect in the schema
            argument = @arguments[element['parameterRef']]
            raise "parameterRef #{element['parameterRef']} not found" unless argument
            argument_type = @argument_types[argument.argumentTypeRef]
            raise "argumentTypeRef #{argument.argumentTypeRef} not found" unless argument_type
            array_type = argument_type
            argument_type = @argument_types[array_type.arrayTypeRef]
            raise "arrayTypeRef #{array_type.arrayTypeRef} not found" unless argument_type
            refName = 'parameterRef'
          else
            argument = @arguments[element['argumentRef']]
            raise "argumentRef #{element['argumentRef']} not found" unless argument
            argument_type = @argument_types[argument.argumentTypeRef]
            raise "argumentTypeRef #{argument.argumentTypeRef} not found" unless argument_type
            refName = 'argumentRef'
          end
          object = argument
          type = argument_type
        end

        bit_size = Integer(type.sizeInBits)

        if array_type
          array_num_items = 1
          # Need to determine dimensions
          xtce_recurse_element(element, depth + 1) do |element, depth|
            if element.name == 'Dimension'
              starting_index = 0
              ending_index = 0
              element.children.each do |child_element|
                if child_element.name == 'StartingIndex'
                  child_element.children.each do |child_element2|
                    if child_element2.name == 'FixedValue'
                      starting_index = child_element2.text.to_i
                    end
                  end
                elsif child_element.name == 'EndingIndex'
                  child_element.children.each do |child_element2|
                    if child_element2.name == 'FixedValue'
                      ending_index = child_element2.text.to_i
                    end
                  end
                  array_num_items *= ((ending_index - starting_index).abs + 1)
                end
                false # Don't recurse again
              end
              false # Don't recurse again
            else
              true # Keep recursing
            end
          end
          array_bit_size = array_num_items * bit_size
        end

        # Add item to packet
        data_type = nil
        case type.xtce_encoding
        when 'IntegerDataEncoding'
          if type.signed == 'false' or type.encoding == 'unsigned'
            data_type = :UINT
          else
            data_type = :INT
          end
        when 'FloatDataEncoding'
          data_type = :FLOAT
        when 'StringDataEncoding'
          data_type = :STRING
        when 'BinaryDataEncoding'
          data_type = :BLOCK
        else
          raise "Referenced Parameter/Argument has no xtce_encoding: #{element[refName]}"
        end

        if bit_offset
          case reference_location
          when 'containerStart'
            item = @current_packet.define_item(object.name, bit_offset, bit_size, data_type, array_bit_size, type.endianness) # overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
          when 'containerEnd'
            item = @current_packet.define_item(object.name, -bit_offset, bit_size, data_type, array_bit_size, type.endianness) # overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
          when 'previousEntry', nil
            item = @current_packet.define_item(object.name, @current_packet.length + bit_offset, bit_size, data_type, array_bit_size, type.endianness) # overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
          when 'nextEntry'
            raise 'nextEntry is not supported'
          end
        else
          item = @current_packet.append_item(object.name, bit_size, data_type, array_bit_size, type.endianness) # overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
        end

        item.description = type.shortDescription if type.shortDescription
        if type.states
          item.states = type.states
        end
        if type.units and type.units_full
          item.units = type.units
          item.units_full = type.units_full
        end
        if @current_cmd_or_tlm == COMMAND
          # Possibly add write conversion
          if type.conversion and type.conversion.class == PolynomialConversion
            item.write_conversion = type.conversion
          end

          # Need to set min, max, and default
          if data_type == :INT or data_type == :UINT
            if data_type == :INT
              item.range = (-(2 ** (Integer(type.sizeInBits) - 1)))..((2 ** (Integer(type.sizeInBits) - 1)) - 1)
            else
              item.range = 0..((2 ** Integer(type.sizeInBits)) - 1)
            end
            if type.minInclusive and type.maxInclusive
              item.range = Integer(type.minInclusive)..Integer(type.maxInclusive)
            end
            if item.array_size
              item.default = []
            else
              item.default = 0
              if item.states and item.states[type.initialValue.to_s.upcase]
                item.default = Integer(item.states[type.initialValue.to_s.upcase])
              else
                item.default = Integer(type.initialValue) if type.initialValue
              end
            end
          elsif data_type == :FLOAT
            if Integer(type.sizeInBits) == 32
              item.range = -3.402823e38..3.402823e38
            else
              item.range = -Float::MAX..Float::MAX
            end
            if type.minInclusive and type.maxInclusive
              item.range = Float(type.minInclusive)..Float(type.maxInclusive)
            end
            if item.array_size
              item.default = []
            else
              item.default = 0.0
              item.default = Float(type.initialValue) if type.initialValue
            end
          elsif data_type == :STRING
            if item.array_size
              item.default = []
            else
              if type.initialValue
                item.default = type.initialValue
              else
                item.default = ''
              end
            end
          elsif data_type == :BLOCK
            if item.array_size
              item.default = []
            else
              if type.initialValue
                item.default = type.initialValue
              else
                item.default = ''
              end
            end
          end
        else
          # Possibly add read conversion
          if type.conversion and type.conversion.class == PolynomialConversion
            item.read_conversion = type.conversion
          end

          # Possibly add default limits
          if type.limits
            item.limits.enabled = true
            values = {}
            values[:DEFAULT] = type.limits
            item.limits.values = values
          end
        end

        return false # Already recursed

      when 'BaseContainer'
        # Handled in SequenceContainer/CommandContainer

      when 'BaseMetaCommand'
        # Handled in MetaCommand

      when 'Comparison'
        # Need to set ID value for item
        item = @current_packet.get_item(element['parameterRef'])
        item.id_value = Integer(element['value'])
        if @current_cmd_or_tlm == COMMAND
          item.default = item.id_value
        end
        @current_packet.update_id_items(item)

      when 'MetaCommand'
        finish_packet()
        @current_packet = Packet.new(@current_target_name, element['name'], :BIG_ENDIAN, element['shortDescription'])
        @current_packet.abstract = ConfigParser.handle_true_false_nil(element['abstract'])
        PacketParser.finish_create_command(@current_packet, @commands, @warnings)

        # Need to check for a BaseContainer now because if we hit it later it will be too late
        xtce_handle_base_container('BaseMetaCommand', element)

      when 'CommandContainer'
        @containers[element['name']] = @current_packet

        # Need to check for a BaseContainer now because if we hit it later it will be too late
        xtce_handle_base_container('BaseContainer', element)

      when 'ArgumentAssignment'
        # Need to set ID value for item
        item = @current_packet.get_item(element['argumentName'])
        value = element['argumentValue']
        if item.states and item.states[value.to_s.upcase]
          item.id_value = item.states[value.to_s.upcase]
          item.default = item.id_value
        else
          item.id_value = Integer(value)
          item.default = item.id_value
        end
        @current_packet.update_id_items(item)

      else
        puts "  Ignoring Unknown: <#{element.name}>"

      end # case element.name

      return true # Recurse further
    end

    def xtce_format_attributes(element)
      string = ''
      element.attributes.each do |att_name, att|
        string << "#{att.name}:#{att.value} "
      end
      if string.length > 0
        string = '( ' + string + ')'
      end
      return string
    end

    def xtce_recurse_element(element, depth, &block)
      return unless yield(element, depth)
      element.children.each do |child_element|
        xtce_recurse_element(child_element, depth + 1, &block)
      end
    end

    def xtce_handle_base_container(base_name, element)
      if element.name == base_name
        # Need to add BaseContainer items to current_packet
        # Lookup the base packet
        if base_name == 'BaseMetaCommand'
          base_packet = @commands[@current_packet.target_name][element['metaCommandRef'].to_s.upcase]
        else
          base_packet = @containers[element['containerRef']]
        end
        if base_packet
          count = 0
          base_packet.sorted_items.each do |item|
            unless ['RECEIVED_TIMESECONDS', 'RECEIVED_TIMEFORMATTED', 'RECEIVED_COUNT'].include?(item.name)
              begin
                @current_packet.get_item(item.name)
              rescue
                # Item hasn't already been added so define it
                @current_packet.define(item.clone)
                count += 1
              end
            end
          end
          return
        else
          if base_name == 'BaseMetaCommand'
            raise "Unknown #{base_name}: #{element['metaCommandRef']}"
          else
            raise "Unknown #{base_name}: #{element['containerRef']}"
          end
        end
      end
      element.children.each do |child_element|
        xtce_handle_base_container(base_name, child_element)
      end
    end

    def xtce_handle_location_in_container_in_bits(element)
      element.children.each do |child_element|
        if child_element.name == 'LocationInContainerInBits'
          child_element.children.each do |child_element2|
            if child_element2.name == 'FixedValue'
              return [child_element['referenceLocation'], Integer(child_element2.text)]
            end
          end
        end
      end
      return [nil, nil]
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

    # Add current packet into hash if it exists
    def finish_packet
      finish_item()
      if @current_packet
        @warnings += @current_packet.check_bit_offsets
        if @current_cmd_or_tlm == COMMAND
          PacketParser.check_item_data_types(@current_packet)
          @commands[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        else
          @telemetry[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        end
        @current_packet = nil
        @current_item = nil
      end
    end

    def start_item(parser)
      finish_item()
      @current_item = PacketItemParser.parse(parser, @current_packet, @current_cmd_or_tlm)
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

  end # class PacketConfig

end # module Cosmos
