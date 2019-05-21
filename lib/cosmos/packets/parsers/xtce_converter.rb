# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'nokogiri'
require 'cosmos/packets/parsers/xtce_parser'

module Cosmos
  class XtceConverter
    attr_accessor :current_target_name

    # Output a previously parsed definition file into the XTCE format
    #
    # @param commands [Hash<String=>Packet>] Hash of all the command packets
    #   keyed by the packet name.
    # @param telemetry [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    #   that were created while parsing the configuration
    # @param output_dir [String] The name of the output directory to generate
    #   the XTCE files. A file is generated for each target.
    def self.convert(commands, telemetry, output_dir)
      XtceConverter.new(commands, telemetry, output_dir)
    end

    private

    def initialize(commands, telemetry, output_dir)
      FileUtils.mkdir_p(output_dir)

      # Build target list
      targets = []
      telemetry.each { |target_name, packets| targets << target_name }
      commands.each { |target_name, packets| targets << target_name }
      targets.uniq!

      targets.each do |target_name|
        next if target_name == 'UNKNOWN'

        # Reverse order of packets for the target so things are expected (reverse) order for xtce
        XtceParser.reverse_packet_order(target_name, commands)
        XtceParser.reverse_packet_order(target_name, telemetry)

        FileUtils.mkdir_p(File.join(output_dir, target_name, 'cmd_tlm'))
        filename = File.join(output_dir, target_name, 'cmd_tlm', target_name.downcase + '.xtce')
        begin
          File.delete(filename)
        rescue
          # Doesn't exist
        end

        # Create the xtce file for this target
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml['xtce'].SpaceSystem("xmlns:xtce" => "http://www.omg.org/space/xtce",
            "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
            "name" => target_name,
            "xsi:schemaLocation" => "http://www.omg.org/space/xtce http://www.omg.org/spec/XTCE/20061101/06-11-06.xsd") do
            create_telemetry(xml, telemetry, target_name)
            create_commands(xml, commands, target_name)
          end # SpaceSystem
        end # builder
        File.open(filename, 'w') do |file|
          file.puts builder.to_xml
        end
      end
    end

    def create_telemetry(xml, telemetry, target_name)
      # Gather and make unique all the packet items
      unique_items = telemetry[target_name] ? get_unique(telemetry[target_name]) : {}

      xml['xtce'].TelemetryMetaData do
        xml['xtce'].ParameterTypeSet do
          unique_items.each do |item_name, item|
            to_xtce_type(item, 'Parameter', xml)
          end
        end

        xml['xtce'].ParameterSet do
          unique_items.each do |item_name, item|
            to_xtce_item(item, 'Parameter', xml)
          end
        end

        if telemetry[target_name]
          xml['xtce'].ContainerSet do
            telemetry[target_name].each do |packet_name, packet|
              attrs = { :name => (packet_name + '_Base'), :abstract => "true" }
              xml['xtce'].SequenceContainer(attrs) do
                process_entry_list(xml, packet, :TELEMETRY)
              end

              attrs = { :name => packet_name }
              attrs['shortDescription'] = packet.description if packet.description
              xml['xtce'].SequenceContainer(attrs) do
                xml['xtce'].EntryList
                xml['xtce'].BaseContainer(:containerRef => (packet_name + '_Base')) do
                  if packet.id_items && packet.id_items.length > 0
                    xml['xtce'].RestrictionCriteria do
                      xml['xtce'].ComparisonList do
                        packet.id_items.each do |item|
                          xml['xtce'].Comparison(:parameterRef => item.name, :value => item.id_value)
                        end
                      end
                    end
                  end
                end
              end # SequenceContainer
            end # telemetry.each
          end # ContainerSet
        end # if telemetry[target_name]
      end # TelemetryMetaData
    end

    def create_commands(xml, commands, target_name)
      return unless commands[target_name]

      xml['xtce'].CommandMetaData do
        xml['xtce'].ArgumentTypeSet do
          get_unique(commands[target_name]).each do |arg_name, arg|
            to_xtce_type(arg, 'Argument', xml)
          end
        end
        xml['xtce'].MetaCommandSet do
          commands[target_name].each do |packet_name, packet|
            attrs = { :name => packet_name + "_Base", :abstract => "true" }
            xml['xtce'].MetaCommand(attrs) do
              xml['xtce'].ArgumentList do
                packet.sorted_items.each do |item|
                  next if item.data_type == :DERIVED
                  to_xtce_item(item, 'Argument', xml)
                end
              end # ArgumentList
              xml['xtce'].CommandContainer(:name => "#{target_name}_#{packet_name}_CommandContainer") do
                process_entry_list(xml, packet, :COMMAND)
              end
            end # Abstract MetaCommand

            attrs = { :name => packet_name }
            attrs['shortDescription'] = packet.description if packet.description
            xml['xtce'].MetaCommand(attrs) do
              xml['xtce'].BaseMetaCommand(:metaCommandRef => packet_name + "_Base") do
                if packet.id_items && packet.id_items.length > 0
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
    end

    def get_unique(items)
      unique = {}
      items.each do |packet_name, packet|
        packet.sorted_items.each do |item|
          next if item.data_type == :DERIVED
          unique[item.name] ||= []
          unique[item.name] << item
        end
      end
      unique.each do |item_name, unique_items|
        if unique_items.length <= 1
          unique[item_name] = unique_items[0]
          next
        end
        # TODO: need to make sure all the items in the array are exactly the same
        unique[item_name] = unique_items[0]
      end
      unique
    end

    # This method is almost the same for commands and telemetry except for the
    # XML element name: [Array]ArgumentRefEntry vs [Array]ParameterRefEntry,
    # and XML reference: argumentRef vs parameterRef.
    # Thus we build the name and use send to dynamically dispatch.
    def process_entry_list(xml, packet, cmd_vs_tlm)
      if cmd_vs_tlm == :COMMAND
        type = "Argument"
      else # :TELEMETRY
        type = "Parameter"
      end
      xml['xtce'].EntryList do
        packed = packet.packed?
        packet.sorted_items.each do |item|
          next if item.data_type == :DERIVED
          # TODO: Handle nonunique item names
          if item.array_size
            # Requiring parameterRef for argument arrays appears to be a defect in the schema
            xml['xtce'].send("Array#{type}RefEntry".intern, :parameterRef => item.name) do
              set_fixed_value(xml, item) if !packed
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
              xml['xtce'].send("#{type}RefEntry".intern, "#{type.downcase}Ref".intern => item.name)
            else
              xml['xtce'].send("#{type}RefEntry".intern, "#{type.downcase}Ref".intern => item.name) do
                set_fixed_value(xml, item)
              end
            end
          end
        end
      end
    end

    def set_fixed_value(xml, item)
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

    def to_xtce_type(item, param_or_arg, xml)
      # TODO: Spline Conversions
      case item.data_type
      when :INT, :UINT
        to_xtce_int(item, param_or_arg, xml)
      when :FLOAT
        to_xtce_float(item, param_or_arg, xml)
      when :STRING
        to_xtce_string(item, param_or_arg, xml, 'String')
      when :BLOCK
        to_xtce_string(item, param_or_arg, xml, 'Binary')
      when :DERIVED
        raise "DERIVED data type not supported in XTCE"
      end

      # Handle arrays
      if item.array_size
        # The above will have created the type for the array entries.   Now we create the type for the actual array.
        attrs = { :name => (item.name + '_ArrayType') }
        attrs[:shortDescription] = item.description if item.description
        attrs[:arrayTypeRef] = (item.name + '_Type')
        attrs[:numberOfDimensions] = '1' # COSMOS Only supports one-dimensional arrays
        xml['xtce'].send('Array' + param_or_arg + 'Type', attrs)
      end
    end

    def to_xtce_limits(item, xml)
      return unless item.limits && item.limits.values
      item.limits.values.each do |limits_set, limits_values|
        if limits_set == :DEFAULT
          xml['xtce'].DefaultAlarm do
            xml['xtce'].StaticAlarmRanges do
              xml['xtce'].WarningRange(:minInclusive => limits_values[1], :maxInclusive => limits_values[2])
              xml['xtce'].CriticalRange(:minInclusive => limits_values[0], :maxInclusive => limits_values[3])
            end
          end
        end
      end
    end

    def to_xtce_int(item, param_or_arg, xml)
      attrs = { :name => (item.name + '_Type') }
      attrs[:initialValue] = item.default if item.default and !item.array_size
      attrs[:shortDescription] = item.description if item.description
      if item.states and item.default and item.states.key(item.default)
        attrs[:initialValue] = item.states.key(item.default) and !item.array_size
      end
      if item.data_type == :INT
        signed = 'true'
        encoding = 'twosCompliment'
      else
        signed = 'false'
        encoding = 'unsigned'
      end
      if item.states
        xml['xtce'].send('Enumerated' + param_or_arg + 'Type', attrs) do
          to_xtce_endianness(item, xml)
          to_xtce_units(item, xml)
          xml['xtce'].IntegerDataEncoding(:sizeInBits => item.bit_size, :encoding => encoding)
          xml['xtce'].EnumerationList do
            item.states.each do |state_name, state_value|
              # Skip the special COSMOS 'ANY' enumerated state
              next if state_value == 'ANY'
              xml['xtce'].Enumeration(:value => state_value, :label => state_name)
            end
          end
        end
      else
        if (item.read_conversion and item.read_conversion.class == PolynomialConversion) or (item.write_conversion and item.write_conversion.class == PolynomialConversion)
          type_string = 'Float' + param_or_arg + 'Type'
        else
          type_string = 'Integer' + param_or_arg + 'Type'
          attrs[:signed] = signed
        end
        xml['xtce'].send(type_string, attrs) do
          to_xtce_endianness(item, xml)
          to_xtce_units(item, xml)
          if (item.read_conversion and item.read_conversion.class == PolynomialConversion) or (item.write_conversion and item.write_conversion.class == PolynomialConversion)
            xml['xtce'].IntegerDataEncoding(:sizeInBits => item.bit_size, :encoding => encoding) do
              to_xtce_conversion(item, xml)
            end
          else
            xml['xtce'].IntegerDataEncoding(:sizeInBits => item.bit_size, :encoding => encoding)
          end
          to_xtce_limits(item, xml)
          if item.range
            xml['xtce'].ValidRange(:minInclusive => item.range.first, :maxInclusive => item.range.last)
          end
        end # Type
      end # if item.states
    end

    def to_xtce_float(item, param_or_arg, xml)
      attrs = { :name => (item.name + '_Type'), :sizeInBits => item.bit_size }
      attrs[:initialValue] = item.default if item.default and !item.array_size
      attrs[:shortDescription] = item.description if item.description
      xml['xtce'].send('Float' + param_or_arg + 'Type', attrs) do
        to_xtce_endianness(item, xml)
        to_xtce_units(item, xml)
        if (item.read_conversion and item.read_conversion.class == PolynomialConversion) or (item.write_conversion and item.write_conversion.class == PolynomialConversion)
          xml['xtce'].FloatDataEncoding(:sizeInBits => item.bit_size, :encoding => 'IEEE754_1985') do
            to_xtce_conversion(item, xml)
          end
        else
          xml['xtce'].FloatDataEncoding(:sizeInBits => item.bit_size, :encoding => 'IEEE754_1985')
        end
        to_xtce_limits(item, xml)
        if item.range
          xml['xtce'].ValidRange(:minInclusive => item.range.first, :maxInclusive => item.range.last)
        end
      end
    end

    def to_xtce_string(item, param_or_arg, xml, string_or_binary)
      # TODO: COSMOS Variably sized strings are not supported in XTCE
      attrs = { :name => (item.name + '_Type') }
      attrs[:characterWidth] = 8 if string_or_binary == 'String'
      if item.default && !item.array_size
        unless item.default.is_printable?
          attrs[:initialValue] = '0x' + item.default.simple_formatted
        else
          attrs[:initialValue] = item.default.inspect
        end
      end
      attrs[:shortDescription] = item.description if item.description
      xml['xtce'].send(string_or_binary + param_or_arg + 'Type', attrs) do
        # Don't call to_xtce_endianness for Strings or Blocks
        to_xtce_units(item, xml)
        if string_or_binary == 'String'
          xml['xtce'].StringDataEncoding(:encoding => 'UTF-8') do
            xml['xtce'].SizeInBits do
              xml['xtce'].Fixed do
                xml['xtce'].FixedValue(item.bit_size.to_s)
              end
            end
          end
        else
          xml['xtce'].BinaryDataEncoding do
            xml['xtce'].SizeInBits do
              xml['xtce'].FixedValue(item.bit_size.to_s)
            end
          end
        end
      end
    end

    def to_xtce_item(item, param_or_arg, xml)
      if item.array_size
        xml['xtce'].send(param_or_arg, :name => item.name, "#{param_or_arg.downcase}TypeRef" => item.name + '_ArrayType')
      else
        xml['xtce'].send(param_or_arg, :name => item.name, "#{param_or_arg.downcase}TypeRef" => item.name + '_Type')
      end
    end

    def to_xtce_units(item, xml)
      if item.units
        xml['xtce'].UnitSet do
          xml['xtce'].Unit(item.units, :description => item.units_full)
        end
      else
        xml['xtce'].UnitSet
      end
    end

    def to_xtce_endianness(item, xml)
      if item.endianness == :LITTLE_ENDIAN and item.bit_size > 8
        xml['xtce'].ByteOrderList do
          (((item.bit_size - 1)/ 8) + 1).times do |byte_significance|
            xml['xtce'].Byte(:byteSignificance => byte_significance)
          end
        end
      end
    end

    def to_xtce_conversion(item, xml)
      if item.read_conversion
        conversion = item.read_conversion
      else
        conversion = item.write_conversion
      end
      if conversion && conversion.class == PolynomialConversion
        xml['xtce'].DefaultCalibrator do
          xml['xtce'].PolynomialCalibrator do
            conversion.coeffs.each_with_index do |coeff, index|
              xml['xtce'].Term(:coefficient => coeff, :exponent => index)
            end
          end
        end
      end
    end
  end
end
