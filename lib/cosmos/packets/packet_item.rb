# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/structure_item'
require 'cosmos/packets/packet_item_limits'
require 'cosmos/conversions/conversion'

module Cosmos

  # Maintains knowledge of an item in a Packet
  class PacketItem < StructureItem
    # @return [String] Printf-style string used to format the item
    attr_reader :format_string

    # Conversion instance used when reading the PacketItem
    # @return [Conversion] Read conversion
    attr_reader :read_conversion

    # Conversion instance used when writing the PacketItem
    # @return [Conversion] Write conversion
    attr_reader :write_conversion

    # The id_value type depends on the data_type of the PacketItem
    # @return Value used to identify a packet
    attr_reader :id_value

    # States are used to convert from a numeric value to a String.
    # @return [Hash] Item states given as STATE_NAME => VALUE
    attr_reader :states

    # @return [String] Description of the item
    attr_reader :description

    # Returns the fully spelled out units of the item. For example,
    # if the item represents a voltage, this would return "Voltage".
    # @return [String] Units of the item
    attr_reader :units_full

    # Returns the abbreviated units of the item. For example,
    # if the item represents a voltage, this would return "V".
    # @return [String] Abbreviated units of the item
    attr_reader :units

    # The default value type depends on the data_type of the PacketItem
    # @return Default value for this item
    attr_accessor :default

    # The valid range of values for this item. Returns nil for items with
    # data_type of :STRING or :BLOCK items.
    # @return [Range] Valid range of values or nil
    attr_reader :range

    # @return [Boolean] Whether this item must be specified or can use its
    # default value. true if it must be specified.
    attr_accessor :required

    # States that are hazardous for this item as well as their descriptions
    # @return [Hash] Hazardous states given as STATE_NAME => DESCRIPTION. If no
    #   description was given the value will be nil.
    attr_reader :hazardous

    # Colors associated with states
    # @return [Hash] State colors given as STATE_NAME => COLOR
    attr_reader :state_colors

    # The allowable state colors
    STATE_COLORS = [:GREEN, :YELLOW, :RED]

    # @return [PacketItemLimits] All information regarding limits for this PacketItem
    attr_reader :limits

    # (see StructureItem#initialize)
    # It also initializes the attributes of the PacketItem.
    def initialize(name, bit_offset, bit_size, data_type, endianness, array_size = nil, overflow = :ERROR)
      super(name, bit_offset, bit_size, data_type, endianness, array_size, overflow)
      @format_string = nil
      @read_conversion = nil
      @write_conversion = nil
      @id_value = nil
      @states = nil
      @description = nil
      @units_full = nil
      @units = nil
      @default = nil
      @range = nil
      @required = false
      @hazardous = nil
      @state_colors = nil
      @limits = PacketItemLimits.new
      @persistence_setting = 1
      @persistence_count = 0
      @meta = nil
    end

    def format_string=(format_string)
      if format_string
        raise ArgumentError, "#{@name}: format_string must be a String but is a #{format_string.class}" unless String === format_string
        raise ArgumentError, "#{@name}: format_string invalid '#{format_string}'" unless format_string =~ /%.*(b|B|d|i|o|u|x|X|e|E|f|g|G|a|A|c|p|s|%)/
        @format_string = format_string.clone.freeze
      else
        @format_string = nil
      end
    end

    def read_conversion=(read_conversion)
      if read_conversion
        raise ArgumentError, "#{@name}: read_conversion must be a Cosmos::Conversion but is a #{read_conversion.class}" unless Cosmos::Conversion === read_conversion
        @read_conversion = read_conversion.clone
      else
        @read_conversion = nil
      end
    end

    def write_conversion=(write_conversion)
      if write_conversion
        raise ArgumentError, "#{@name}: write_conversion must be a Cosmos::Conversion but is a #{write_conversion.class}" unless Cosmos::Conversion === write_conversion
        @write_conversion = write_conversion.clone
      else
        @write_conversion = nil
      end
    end

    def id_value=(id_value)
      if id_value
        @id_value = convert(id_value, @data_type)
      else
        @id_value = nil
      end
    end

    # Assignment operator for states to make sure it is a Hash with uppercase keys
    def states=(states)
      if states
        raise ArgumentError, "#{@name}: states must be a Hash but is a #{states.class}" unless Hash === states

        # Make sure all states are in upper case
        upcase_states = {}
        states.each do |key, value|
          upcase_states[key.to_s.upcase] = value
        end

        @states = upcase_states
        @state_colors ||= {}
      else
        @states = nil
      end
    end

    def description=(description)
      if description
        raise ArgumentError, "#{@name}: description must be a String but is a #{description.class}" unless String === description
        @description = description.clone.freeze
      else
        @description = nil
      end
    end

    def units_full=(units_full)
      if units_full
        raise ArgumentError, "#{@name}: units_full must be a String but is a #{units_full.class}" unless String === units_full
        @units_full = units_full.clone.freeze
      else
        @units_full = nil
      end
    end

    def units=(units)
      if units
        raise ArgumentError, "#{@name}: units must be a String but is a #{units.class}" unless String === units
        @units = units.clone.freeze
      else
        @units = nil
      end
    end

    def check_default_and_range_data_types
      if @default and !@write_conversion
        if @array_size
          raise ArgumentError, "#{@name}: default must be an Array but is a #{default.class}" unless Array === @default
        else
          case data_type
          when :INT, :UINT
            raise ArgumentError, "#{@name}: default must be a Integer but is a #{@default.class}" unless Integer === @default
            if @range
              raise ArgumentError, "#{@name}: minimum must be a Integer but is a #{@range.first.class}" unless Integer === @range.first
              raise ArgumentError, "#{@name}: maximum must be a Integer but is a #{@range.last.class}" unless Integer === @range.last
            end
          when :FLOAT
            raise ArgumentError, "#{@name}: default must be a Float but is a #{@default.class}" unless Float === @default or Integer === @default
            @default = @default.to_f
            if @range
              raise ArgumentError, "#{@name}: minimum must be a Float but is a #{@range.first.class}" unless Float === @range.first or Integer === @range.first
              raise ArgumentError, "#{@name}: maximum must be a Float but is a #{@range.last.class}" unless Float === @range.last or Integer === @range.last
              @range = ((@range.first.to_f)..(@range.last.to_f))
            end
          when :BLOCK, :STRING
            raise ArgumentError, "#{@name}: default must be a String but is a #{@default.class}" unless String === @default
            @default = @default.clone.freeze
          end
        end
      end
    end

    def range=(range)
      if range
        raise ArgumentError, "#{@name}: range must be a Range but is a #{range.class}" unless Range === range
        @range = range.clone.freeze
      else
        @range = nil
      end
    end

    def hazardous=(hazardous)
      if hazardous
        raise ArgumentError, "#{@name}: hazardous must be a Hash but is a #{hazardous.class}" unless Hash === hazardous
        @hazardous = hazardous.clone
      else
        @hazardous = nil
      end
    end

    def state_colors=(state_colors)
      if state_colors
        raise ArgumentError, "#{@name}: state_colors must be a Hash but is a #{state_colors.class}" unless Hash === state_colors
        @state_colors = state_colors.clone
      else
        @state_colors = nil
      end
    end

    def limits=(limits)
      if limits
        raise ArgumentError, "#{@name}: limits must be a PacketItemLimits but is a #{limits.class}" unless PacketItemLimits === limits
        @limits = limits.clone
      else
        @limits = nil
      end
    end

    def meta
      @meta ||= {}
    end

    # Make a light weight clone of this item
    def clone
      item = super()
      item.format_string = self.format_string.clone if self.format_string
      item.read_conversion = self.read_conversion.clone if self.read_conversion
      item.write_conversion = self.write_conversion.clone if self.write_conversion
      item.states = self.states.clone if self.states
      item.description = self.description.clone if self.description
      item.units_full = self.units_full.clone if self.units_full
      item.units = self.units.clone if self.units
      item.default = self.default.clone if self.default and String === self.default
      item.hazardous = self.hazardous.clone if self.hazardous
      item.state_colors = self.state_colors.clone if self.state_colors
      item.limits = self.limits.clone if self.limits
      item.meta = self.meta.clone if @meta
      item
    end
    alias dup clone

    def to_hash
      hash = super()
      hash['format_string'] = self.format_string
      if self.read_conversion
        hash['read_conversion'] = self.read_conversion.to_s
      else
        hash['read_conversion'] = nil
      end
      if self.write_conversion
        hash['write_conversion'] = self.write_conversion.to_s
      else
        hash['write_conversion'] = nil
      end
      hash['id_value'] = self.id_value
      hash['states'] = self.states
      hash['description'] = self.description
      hash['units_full'] = self.units_full
      hash['units'] = self.units
      hash['default'] = self.default
      hash['range'] = self.range
      hash['required'] = self.required
      hash['hazardous'] = self.hazardous
      hash['state_colors'] = self.state_colors
      hash['limits'] = self.limits.to_hash
      hash['meta'] = nil
      hash['meta'] = @meta if @meta
      hash
    end

    def to_config(cmd_or_tlm, default_endianness)
      config = ''
      if cmd_or_tlm == :TELEMETRY
        if self.array_size
          config << "  ARRAY_ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.array_size} \"#{self.description.to_s.gsub("\"", "'")}\""
        elsif self.id_value
          config << "  ID_ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.id_value} \"#{self.description.to_s.gsub("\"", "'")}\""
        else
          config << "  ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} \"#{self.description.to_s.gsub("\"", "'")}\""
        end
      else # :COMMAND
        if self.array_size
          config << "  ARRAY_PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.array_size} \"#{self.description.to_s.gsub("\"", "'")}\""
        elsif self.id_value
          if self.data_type == :BLOCK or self.data_type == :STRING
            config << "  ID_PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} \"#{self.default}\" \"#{self.description.to_s.gsub("\"", "'")}\""
          else
            config << "  ID_PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.range.first} #{self.range.last} #{self.default} \"#{self.description.to_s.gsub("\"", "'")}\""
          end
        else
          if self.data_type == :BLOCK or self.data_type == :STRING
            config << "  PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} \"#{self.default}\" \"#{self.description.to_s.gsub("\"", "'")}\""
          else
            config << "  PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.range.first} #{self.range.last} #{self.default} \"#{self.description.to_s.gsub("\"", "'")}\""
          end
        end
      end
      config << " #{self.endianness}" if self.endianness != default_endianness
      config << "\n"

      config << "    REQUIRED\n" if self.required
      config << "    FORMAT_STRING #{self.format_string.to_s.quote_if_necessary}\n" if self.format_string
      config << "    UNITS #{self.units_full.to_s.quote_if_necessary} #{self.units.to_s.quote_if_necessary}\n" if self.units
      config << "    OVERFLOW #{self.overflow}\n" if self.overflow != :ERROR

      if @states
        @states.each do |state_name, state_value|
          config << "    STATE #{state_name.to_s.quote_if_necessary} #{state_value.to_s.quote_if_necessary}"
          if @hazardous and @hazardous[state_name]
            config << " HAZARDOUS #{@hazardous[state_name].to_s.quote_if_necessary}"
          end
          if @state_colors and @state_colors[state_name]
            config << " #{@state_colors[state_name]}"
          end
          config << "\n"
        end
      end

      config << self.read_conversion.to_config(:READ) if self.read_conversion
      config << self.write_conversion.to_config(:WRITE) if self.write_conversion

      if self.limits
        if self.limits.values
          self.limits.values.each do |limits_set, limits_values|
            config << "    LIMITS #{limits_set} #{self.limits.persistence_setting} #{self.limits.enabled ? 'ENABLED' : 'DISABLED'} #{limits_values[0]} #{limits_values[1]} #{limits_values[2]} #{limits_values[3]} #{limits_values[4]} #{limits_values[5]}\n"
          end
        end
        config << self.limits.response.to_config if self.limits.response
      end

      if @meta
        @meta.each do |key, values|
          config << "    META #{key.to_s.quote_if_necessary} #{values.map {|a| a.to_s.quote_if_necessary}.join(" ")}\n"
        end
      end

      config
    end

    def to_xtce_type(param_or_arg, xml)
      # TODO: Spline Conversions
      case self.data_type
      when :INT, :UINT
        attrs = { :name => (self.name + '_Type') }
        attrs[:initialValue] = self.default if self.default and !self.array_size
        attrs[:shortDescription] = self.description if self.description
        if @states and self.default and @states.key(self.default)
          attrs[:initialValue] = @states.key(self.default) and !self.array_size
        end
        if self.data_type == :INT
          signed = 'true'
          encoding = 'twosCompliment'
        else
          signed = 'false'
          encoding = 'unsigned'
        end
        if @states
			    xml['xtce'].send('Enumerated' + param_or_arg + 'Type', attrs) do
            to_xtce_endianness(xml)
            to_xtce_units(xml)
            xml['xtce'].IntegerDataEncoding(:sizeInBits => self.bit_size, :encoding => encoding)
				    xml['xtce'].EnumerationList do
              @states.each do |state_name, state_value|
					      xml['xtce'].Enumeration(:value => state_value, :label => state_name)
              end
            end
          end
        else
          if (self.read_conversion and self.read_conversion.class == PolynomialConversion) or (self.write_conversion and self.write_conversion.class == PolynomialConversion)
            type_string = 'Float' + param_or_arg + 'Type'
          else
            type_string = 'Integer' + param_or_arg + 'Type'
            attrs[:signed] = signed
          end
          xml['xtce'].send(type_string, attrs) do
            to_xtce_endianness(xml)
            to_xtce_units(xml)
            if (self.read_conversion and self.read_conversion.class == PolynomialConversion) or (self.write_conversion and self.write_conversion.class == PolynomialConversion)
              xml['xtce'].IntegerDataEncoding(:sizeInBits => self.bit_size, :encoding => encoding) do
                to_xtce_conversion(xml)
              end
            else
              xml['xtce'].IntegerDataEncoding(:sizeInBits => self.bit_size, :encoding => encoding)
            end
            if self.limits
              if self.limits.values
                self.limits.values.each do |limits_set, limits_values|
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
            end
            if self.range
              xml['xtce'].ValidRange(:minInclusive => self.range.first, :maxInclusive => self.range.last)
            end
          end # Type
        end # if @states
      when :FLOAT
        attrs = { :name => (self.name + '_Type'), :sizeInBits => self.bit_size }
        attrs[:initialValue] = self.default if self.default and !self.array_size
        attrs[:shortDescription] = self.description if self.description
        xml['xtce'].send('Float' + param_or_arg + 'Type', attrs) do
          to_xtce_endianness(xml)
          to_xtce_units(xml)
          if (self.read_conversion and self.read_conversion.class == PolynomialConversion) or (self.write_conversion and self.write_conversion.class == PolynomialConversion)
            xml['xtce'].FloatDataEncoding(:sizeInBits => self.bit_size, :encoding => 'IEEE754_1985') do
              to_xtce_conversion(xml)
            end
          else
            xml['xtce'].FloatDataEncoding(:sizeInBits => self.bit_size, :encoding => 'IEEE754_1985')
          end

          if self.limits
            if self.limits.values
              self.limits.values.each do |limits_set, limits_values|
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
          end

          if self.range
            xml['xtce'].ValidRange(:minInclusive => self.range.first, :maxInclusive => self.range.last)
          end

        end # Type
      when :STRING
        # TODO: COSMOS Variably sized strings are not supported in XTCE
        attrs = { :name => (self.name + '_Type'), :characterWidth => 8 }
        attrs[:initialValue] = self.default if self.default and !self.array_size
        attrs[:shortDescription] = self.description if self.description
        xml['xtce'].send('String' + param_or_arg + 'Type', attrs) do
          to_xtce_endianness(xml)
          to_xtce_units(xml)
          xml['xtce'].StringDataEncoding(:encoding => 'UTF-8') do
					  xml['xtce'].SizeInBits do
              xml['xtce'].Fixed do
                xml['xtce'].FixedValue(self.bit_size.to_s)
              end
            end
          end
        end
      when :BLOCK
        # TODO: COSMOS Variably sized blocks are not supported in XTCE
        # TODO: Write string to hex method to support initial value
        attrs = { :name => (self.name + '_Type') }
        attrs[:shortDescription] = self.description if self.description
        #attrs[:initialValue] = self.default if self.default and !self.array_size
        xml['xtce'].send('Binary' + param_or_arg + 'Type', attrs) do
          to_xtce_endianness(xml)
          to_xtce_units(xml)
          xml['xtce'].BinaryDataEncoding do
					  xml['xtce'].SizeInBits do
              xml['xtce'].FixedValue(self.bit_size.to_s)
            end
          end
        end
      when :DERIVED
        raise "DERIVED data type not supported in XTCE"
      end

      # Handle arrays
      if self.array_size
        # The above will have created the type for the array entries.   Now we create the type for the actual array.
        attrs = { :name => (self.name + '_ArrayType') }
        attrs[:shortDescription] = self.description if self.description
        attrs[:arrayTypeRef] = (self.name + '_Type')
        attrs[:numberOfDimensions] = '1' # COSMOS Only supports one-dimensional arrays
        xml['xtce'].send('Array' + param_or_arg + 'Type', attrs)
      end
    end

    def to_xtce_item(param_or_arg, xml)
      if self.array_size
        xml['xtce'].send(param_or_arg, :name => self.name, "#{param_or_arg.downcase}TypeRef" => self.name + '_ArrayType')
      else
        xml['xtce'].send(param_or_arg, :name => self.name, "#{param_or_arg.downcase}TypeRef" => self.name + '_Type')
      end
    end

    protected

    def to_xtce_units(xml)
      if self.units
        xml['xtce'].UnitSet do
          xml['xtce'].Unit(self.units, :description => self.units_full)
        end
      else
        xml['xtce'].UnitSet
      end
    end

    def to_xtce_endianness(xml)
      if self.endianness == :LITTLE_ENDIAN and self.bit_size > 8
        xml['xtce'].ByteOrderList do
          (((self.bit_size - 1)/ 8) + 1).times do |byte_significance|
            xml['xtce'].Byte(:byteSignificance => byte_significance)
          end
        end
      end
    end

    def to_xtce_conversion(xml)
      if self.read_conversion
        conversion = self.read_conversion
      else
        conversion = self.write_conversion
      end
      if conversion and conversion.class == PolynomialConversion
        xml['xtce'].DefaultCalibrator do
					xml['xtce'].PolynomialCalibrator do
            conversion.coeffs.each_with_index do |coeff, index|
						  xml['xtce'].Term(:coefficient => coeff, :exponent => index)
            end
					end
        end
      end
    end

    # Convert a value into the given data type
    def convert(value, data_type)
      case data_type
      when :INT, :UINT
        Integer(value)
      when :FLOAT
        Float(value)
      when :STRING, :BLOCK
        value.to_s.freeze
      end
    rescue
      raise ArgumentError, "#{@name}: Invalid value: #{value} for data type: #{data_type}"
    end

  end # class PacketItem

end # module Cosmos
