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
    # @param target_name [String] Override the target name found in the XTCE file
    def self.process(commands, telemetry, warnings, filename, target_name = nil)
      XtceParser.new(commands, telemetry, warnings, filename, target_name)
    end

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

    private

    def initialize(commands, telemetry, warnings, filename, target_name = nil)
      reset_processing_variables()
      @commands = commands
      @telemetry = telemetry
      @warnings = warnings
      @current_packet = nil
      parse(filename, target_name)
    end

    def parse(filename, target_name)
      doc = File.open(filename) { |f| Nokogiri::XML(f, nil, nil, Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NOBLANKS) }
      # Determine the @current_target_name
      xtce_process_element(doc.root)
      @current_target_name = target_name if target_name
      doc.root.children.each do |child|
        xtce_recurse_element(child) do |element|
          xtce_process_element(element)
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
        set_packet_endianness()
        if @current_cmd_or_tlm == PacketConfig::COMMAND
          PacketParser.check_item_data_types(@current_packet)
          @commands[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        else
          @telemetry[@current_packet.target_name][@current_packet.packet_name] = @current_packet
        end
        @current_packet = nil
      end
    end

    def set_packet_endianness
      item_endianness = @current_packet.sorted_items.collect do |item|
        # Strings and Blocks endianness don't matter so ignore them
        item.endianness if (item.data_type != :STRING && item.data_type != :BLOCK)
      end
      # Compact to get rid of nils from skipping Strings and Blocks
      # Uniq to get rid of duplicates which results in an array of 1 or 2 items
      item_endianness = item_endianness.compact.uniq
      if item_endianness.length == 1 # All items have the same endianness
        # default_endianness is read_only since it affects how items are added
        # thus we have to use instance_variable_set here to override it
        @current_packet.instance_variable_set(:@default_endianness, item_endianness[0])
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

    def create_new_type(element)
      current_type = OpenStruct.new
      element.attributes.each do |att_name, att|
        current_type[att.name] = att.value
      end
      if element.name =~ /Argument/
        @argument_types[element["name"]] = current_type
      else
        @parameter_types[element["name"]] = current_type
      end
      current_type
    end

    XTCE_IGNORED_ELEMENTS = ['text', 'AliasSet', 'Alias', 'Header']

    def xtce_process_element(element)
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

      when 'ParameterTypeSet', 'EnumerationList', 'ParameterSet', 'ContainerSet',
        'EntryList', 'DefaultCalibrator', 'DefaultAlarm', 'RestrictionCriteria',
        'ComparisonList', 'MetaCommandSet', 'ArgumentTypeSet', 'ArgumentList',
        'ArgumentAssignmentList', 'LocationInContainerInBits'
        # Do Nothing

      when 'EnumeratedParameterType', 'EnumeratedArgumentType',
        'IntegerParameterType', 'IntegerArgumentType',
        'FloatParameterType', 'FloatArgumentType',
        'StringParameterType', 'StringArgumentType',
        'BinaryParameterType', 'BinaryArgumentType'
        @current_type = create_new_type(element)
        @current_type.endianness = :BIG_ENDIAN

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
        @current_type = create_new_type(element)

      when 'ByteOrderList'
        byte_list = []
        xtce_recurse_element(element) do |block_element|
          if block_element.name == 'Byte'
            if block_element['byteSignificance']
              byte_list << block_element['byteSignificance'].to_i
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
        xtce_recurse_element(element) do |block_element|
          if block_element.name == 'FixedValue'
            @current_type.sizeInBits = Integer(block_element.text)
            false
          else
            true
          end
        end
        return false # Already recursed

      when 'UnitSet'
        xtce_recurse_element(element) do |block_element|
          if block_element.name == 'Unit'
            units = block_element.text.to_s
            description = block_element['description'].to_s
            description = units if description.empty?
            units = description if units.empty?

            @current_type.units ||= ''
            if @current_type.units.empty?
              @current_type.units << units
            else
              @current_type.units << ('/' + units)
            end
            @current_type.units << "^#{block_element['power']}" if block_element['power']

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
        xtce_recurse_element(element) do |block_element|
          if block_element.name == 'Term'
            exponent = Float(block_element['exponent']).to_i
            @current_type.conversion ||= PolynomialConversion.new([])
            @current_type.conversion.coeffs[exponent] = Float(block_element['coefficient'])
            @current_type.conversion.coeffs.each_with_index do |value, index|
              @current_type.conversion.coeffs[index] = 0.0 if value.nil?
            end
          end
          true
        end
        return false # Already recursed

      when 'StaticAlarmRanges'
        xtce_recurse_element(element) do |block_element|
          if block_element.name == 'WarningRange'
            @current_type.limits ||= [0.0, 0.0, 0.0, 0.0]
            @current_type.limits[1] = Float(block_element['minInclusive']) if block_element['minInclusive']
            @current_type.limits[2] = Float(block_element['maxInclusive']) if block_element['maxInclusive']
          elsif block_element.name == 'CriticalRange'
            @current_type.limits ||= [0.0, 0.0, 0.0, 0.0]
            @current_type.limits[0] = Float(block_element['minInclusive']) if block_element['minInclusive']
            @current_type.limits[3] = Float(block_element['maxInclusive']) if block_element['maxInclusive']
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
        if @current_packet && !@current_packet.description
          @current_packet.description = element.text
        end

      when 'ParameterRefEntry', 'ArgumentRefEntry', 'ArrayParameterRefEntry', 'ArrayArgumentRefEntry'
        process_ref_entry(element)
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
        if item.states && item.states[value.to_s.upcase]
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

    def process_ref_entry(element)
      reference_location, bit_offset = xtce_handle_location_in_container_in_bits(element)
      object, type, data_type, array_type = get_object_types(element)
      bit_size = Integer(type.sizeInBits)
      if array_type
        array_bit_size = process_array_type(element, bit_size)
      else
        array_bit_size = nil # in define_item, nil indicates the item is not an array
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
      item.states = type.states if type.states
      set_units(item, type)
      set_conversion(item, type, data_type)
      set_min_max_default(item, type, data_type)
      set_limits(item, type)
    end

    def get_object_types(element)
      array_type = nil
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

      data_type = get_data_type(type)
      raise "Referenced Parameter/Argument has no xtce_encoding: #{element[refName]}" unless data_type

      return [object, type, data_type, array_type]
    end

    def process_array_type(element, bit_size)
      array_num_items = 1
      # Need to determine dimensions
      xtce_recurse_element(element) do |block_element|
        if block_element.name == 'Dimension'
          starting_index = 0
          ending_index = 0
          block_element.children.each do |child_element|
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
      array_num_items * bit_size
    end

    def get_data_type(type)
      data_type = nil
      case type.xtce_encoding
      when 'IntegerDataEncoding'
        if type.signed == 'false' || type.encoding == 'unsigned'
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
      end
      data_type
    end

    def set_units(item, type)
      if type.units && type.units_full
        item.units = type.units
        item.units_full = type.units_full
      end
    end

    def set_conversion(item, type, data_type)
      if type.conversion && type.conversion.class == PolynomialConversion
        if @current_cmd_or_tlm == PacketConfig::COMMAND
          item.write_conversion = type.conversion
        else
          item.read_conversion = type.conversion
        end
      end
    end

    def set_min_max_default(item, type, data_type)
      return unless @current_cmd_or_tlm == PacketConfig::COMMAND
        # Need to set min, max, and default
      if data_type == :INT || data_type == :UINT
        if data_type == :INT
          item.range = (-(2 ** (Integer(type.sizeInBits) - 1)))..((2 ** (Integer(type.sizeInBits) - 1)) - 1)
        else
          item.range = 0..((2 ** Integer(type.sizeInBits)) - 1)
        end
        if type.minInclusive && type.maxInclusive
          item.range = Integer(type.minInclusive)..Integer(type.maxInclusive)
        end
        if item.array_size
          item.default = []
        else
          item.default = 0
          if item.states && item.states[type.initialValue.to_s.upcase]
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
        if type.minInclusive && type.maxInclusive
          item.range = Float(type.minInclusive)..Float(type.maxInclusive)
        end
        if item.array_size
          item.default = []
        else
          item.default = 0.0
          item.default = Float(type.initialValue) if type.initialValue
        end
      elsif data_type == :STRING || data_type == :BLOCK
        if item.array_size
          item.default = []
        else
          if type.initialValue
            if type.initialValue.upcase.start_with?("0X")
              item.default = type.initialValue.hex_to_byte_string
            else
              # Strip quotes from strings
              if type.initialValue[0] == '"' && type.initialValue[-1] == '"'
                item.default = type.initialValue[1..-2]
              end
            end
          else
            item.default = ''
          end
        end
      end
    end

    def set_limits(item, type)
      return unless @current_cmd_or_tlm == PacketConfig::TELEMETRY
      if type.limits
        item.limits.enabled = true
        values = {}
        values[:DEFAULT] = type.limits
        item.limits.values = values
      end
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

    def xtce_recurse_element(element, &block)
      return unless yield(element)
      element.children.each do |child_element|
        xtce_recurse_element(child_element, &block)
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
            unless ['PACKET_TIMESECONDS', 'PACKET_TIMEFORMATTED', 'RECEIVED_TIMESECONDS', 'RECEIVED_TIMEFORMATTED', 'RECEIVED_COUNT'].include?(item.name)
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
