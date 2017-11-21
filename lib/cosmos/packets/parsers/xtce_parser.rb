# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'nokogiri'
require 'ostruct'
require 'cosmos/packets/packet_config'

module Cosmos

  class XtceParser
    attr_accessor :current_target_name

    # Processes a XTCE formatted COSMOS configuration file
    #
    # @param commands [Hash<String=>Packet>] Hash of all the command packets
    #   keyed by the packet name.
    # @param telemetry [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    # @param warnings [Array<String>] Array of strings listing all the warnings
    #   that were created while parsing the configuration
    # @param filename [String] The name of the configuration file
    # @param target_name [String] The target name
    def self.process(commands, telemetry, warnings, filename, target_name)
      XtceParser.new(commands, telemetry, warnings, filename, target_name)
    end

    # Output a previously parsed definition file into the XTCE format
    #
    # @param commands [Hash<String=>Packet>] Hash of all the command packets
    #   keyed by the packet name.
    # @param telemetry [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    #   that were created while parsing the configuration
    # @param output_dir [String] The name of the output directory to generate
    #   the XTCE files. A file is generated for each target.
    def self.to_xtce(commands, telemetry, output_dir)
      FileUtils.mkdir_p(output_dir)

      # Build target list
      targets = []
      telemetry.each { |target_name, packets| targets << target_name }
      commands.each { |target_name, packets| targets << target_name }
      targets.uniq!

      targets.each do |target_name|
        next if target_name == 'UNKNOWN'

        # Reverse order of packets for the target so things are expected (reverse) order for xtce
        reverse_packet_order(target_name, commands)
        reverse_packet_order(target_name, telemetry)

        FileUtils.mkdir_p(File.join(output_dir, target_name, 'cmd_tlm'))
        filename = File.join(output_dir, target_name, 'cmd_tlm', target_name.downcase + '.xtce')
        begin
          File.delete(filename)
        rescue
          # Doesn't exist
        end

        # Gather and make unique all the packet items
        unique_items = {}
        if telemetry[target_name]
          telemetry[target_name].each do |packet_name, packet|
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
        end

        # Gather and make unique all the command parameters
        unique_arguments = {}
        if commands[target_name]
          commands[target_name].each do |packet_name, packet|
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

              if telemetry[target_name]
                xml['xtce'].ContainerSet do
                  telemetry[target_name].each do |packet_name, packet|
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

                  end # telemetry.each
                end # ContainerSet
              end # TelemetryMetaData
            end # if telemetry[target_name]

            if commands[target_name]
              xml['xtce'].CommandMetaData do
                xml['xtce'].ArgumentTypeSet do
                  unique_arguments.each do |arg_name, arg|
                    arg.to_xtce_type('Argument', xml)
                  end
                end
                xml['xtce'].MetaCommandSet do
                  commands[target_name].each do |packet_name, packet|
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
                  end # commands.each
                end # MetaCommandSet
              end # CommandMetaData
            end # if commands[target_name]
          end # SpaceSystem
        end # builder
        File.open(filename, 'w') do |file|
          file.puts builder.to_xml
        end
      end
    end

    private

    def self.reverse_packet_order(target_name, cmd_or_tlm_hash)
      if cmd_or_tlm_hash[target_name]
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
    end

    # Create a new XtceParser
    #
    # @param commands [Hash<String=>Packet>] Hash of all the command packets
    #   keyed by the packet name.
    # @param telemetry [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    # @param warnings [Array<String>] Array of strings listing all the warnings
    #   that were created while parsing the configuration
    # @param filename [String] The name of the configuration file
    # @param target_name [String] The target name
    def initialize(commands, telemetry, warnings, filename, target_name)
      reset_processing_variables()
      @commands = commands
      @telemetry = telemetry
      @warnings = warnings
      parse(filename, target_name)
    end

    def parse(filename, target_name)
      doc = File.open(filename) { |f| Nokogiri::XML(f, nil, nil, Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NOBLANKS) }
      xtce_process_element(doc.root, 0)
      @current_target_name = target_name if target_name
      doc.root.children.each do |child|
        xtce_recurse_element(child, 1) do |element, depth|
          xtce_process_element(element, depth)
        end
      end
      finish_packet()

      # Remove abstract
      if @commands[@current_target_name]
        @commands[@current_target_name].delete_if {|packet_name, packet| packet.abstract}
      end
      if @telemetry[@current_target_name]
        @telemetry[@current_target_name].delete_if {|packet_name, packet| packet.abstract}
      end

      # Reverse order of packets for the target so ids work correctly
      XtceParser.reverse_packet_order(@current_target_name, @commands)
      XtceParser.reverse_packet_order(@current_target_name, @telemetry)

      reset_processing_variables()
    end

    # Add current packet into hash if it exists
    def finish_packet()
      if @current_packet
        @warnings += @current_packet.check_bit_offsets
        if @current_cmd_or_tlm == PacketConfig::COMMAND
          PacketParser.check_item_data_types(@current_packet)
          @commands[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        else
          @telemetry[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        end
        @current_packet = nil
      end
    end

    def reset_processing_variables
      @current_target_name = nil
      @current_cmd_or_tlm = nil
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
        @current_cmd_or_tlm = PacketConfig::TELEMETRY

      when 'CommandMetaData'
        finish_packet()
        @current_cmd_or_tlm = PacketConfig::COMMAND

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
        byte_list = []
        xtce_recurse_element(element, depth + 1) do |element, depth|
          if element.name == 'Byte'
            if element['byteSignificance']
              byte_list << element['byteSignificance'].to_i
            end
          end
          true
        end
        if byte_list[0] == 0
          # Little endian will always start with 0 - Its ok if a single byte item is marked little endian
          @current_type.endianness = :LITTLE_ENDIAN
        end

        # Verify ordering of byte list is supported
        if byte_list[0] >= byte_list[-1]
          ordered_byte_list = byte_list.reverse
        else
          ordered_byte_list = byte_list.clone
        end
        if ordered_byte_list[0] != 0
          msg = "Invalid ByteOrderList detected: #{byte_list.join(", ")}"
          Logger.instance.warn msg
          @warnings << msg
        else
          previous_byte = nil
          ordered_byte_list.each do |byte|
            if previous_byte
              if byte - previous_byte != 1
                msg = "Invalid ByteOrderList detected: #{byte_list.join(", ")}"
                Logger.instance.warn msg
                @warnings << msg
                break
              end
            end
            previous_byte = byte
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
            units = element.text.to_s
            description = element['description'].to_s
            description = units if description.empty?
            units = description if units.empty?

            @current_type.units ||= ''
            if @current_type.units.empty?
              @current_type.units << units
            else
              @current_type.units << ('/' + units)
            end
            @current_type.units << "^#{element['power']}" if element['power']

            @current_type.units_full ||= ''
            if @current_type.units_full.empty?
              @current_type.units_full << description
            else
              @current_type.units_full << ('/' + description)
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
        PacketParser.finish_create_telemetry(@current_packet, @telemetry, {}, @warnings)

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
        if @current_cmd_or_tlm == PacketConfig::COMMAND
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
        if @current_cmd_or_tlm == PacketConfig::COMMAND
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
  end
end
