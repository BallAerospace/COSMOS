# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/packets/structure_item'
require 'openc3/packets/packet_item_limits'
require 'openc3/conversions/conversion'
require 'openc3/io/json_rpc' # Includes needed as_json code

module OpenC3
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
        raise ArgumentError, "#{@name}: format_string invalid '#{format_string}'" unless /%.*(b|B|d|i|o|u|x|X|e|E|f|g|G|a|A|c|p|s|%)/.match?(format_string)

        @format_string = format_string.clone.freeze
      else
        @format_string = nil
      end
    end

    def read_conversion=(read_conversion)
      if read_conversion
        raise ArgumentError, "#{@name}: read_conversion must be a OpenC3::Conversion but is a #{read_conversion.class}" unless OpenC3::Conversion === read_conversion

        @read_conversion = read_conversion.clone
      else
        @read_conversion = nil
      end
    end

    def write_conversion=(write_conversion)
      if write_conversion
        raise ArgumentError, "#{@name}: write_conversion must be a OpenC3::Conversion but is a #{write_conversion.class}" unless OpenC3::Conversion === write_conversion

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

        @description = description.to_utf8.freeze
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

    def meta=(meta)
      if meta
        raise ArgumentError, "#{@name}: meta must be a Hash but is a #{meta.class}" unless Hash === meta

        @meta = meta.clone
      else
        @meta = nil
      end
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

    def calculate_range
      first = range.first
      last = range.last
      if data_type == :FLOAT
        if bit_size == 32
          if range.first == -3.402823e38
            first = 'MIN'
          end
          if range.last == 3.402823e38
            last = 'MAX'
          end
        else
          if range.first == -Float::MAX
            first = 'MIN'
          end
          if range.last == Float::MAX
            last = 'MAX'
          end
        end
      end
      return [first, last]
    end

    def to_config(cmd_or_tlm, default_endianness)
      config = ''
      if cmd_or_tlm == :TELEMETRY
        if self.array_size
          config << "  ARRAY_ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.array_size} \"#{self.description.to_s.gsub("\"", "'")}\""
        elsif self.id_value
          id_value = self.id_value
          if self.data_type == :BLOCK || self.data_type == :STRING
            unless self.id_value.is_printable?
              id_value = "0x" + self.id_value.simple_formatted
            else
              id_value = "\"#{self.id_value}\""
            end
          end
          config << "  ID_ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{id_value} \"#{self.description.to_s.gsub("\"", "'")}\""
        else
          config << "  ITEM #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} \"#{self.description.to_s.gsub("\"", "'")}\""
        end
      else # :COMMAND
        if self.array_size
          config << "  ARRAY_PARAMETER #{self.name.to_s.quote_if_necessary} #{self.bit_offset} #{self.bit_size} #{self.data_type} #{self.array_size} \"#{self.description.to_s.gsub("\"", "'")}\""
        else
          config << parameter_config()
        end
      end
      config << " #{self.endianness}" if self.endianness != default_endianness && self.data_type != :STRING && self.data_type != :BLOCK
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
            config << "    LIMITS #{limits_set} #{self.limits.persistence_setting} #{self.limits.enabled ? 'ENABLED' : 'DISABLED'} #{limits_values[0]} #{limits_values[1]} #{limits_values[2]} #{limits_values[3]}"
            if limits_values[4] && limits_values[5]
              config << " #{limits_values[4]} #{limits_values[5]}\n"
            else
              config << "\n"
            end
          end
        end
        config << self.limits.response.to_config if self.limits.response
      end

      if @meta
        @meta.each do |key, values|
          config << "    META #{key.to_s.quote_if_necessary} #{values.map { |a| a.to_s.quote_if_necessary }.join(" ")}\n"
        end
      end

      config
    end

    def as_json(*a)
      config = {}
      config['name'] = self.name
      config['bit_offset'] = self.bit_offset
      config['bit_size'] = self.bit_size
      config['data_type'] = self.data_type.to_s
      config['array_size'] = self.array_size if self.array_size
      config['description'] = self.description
      config['id_value'] = self.id_value.as_json(*a) if self.id_value
      if @default
        config['default'] = @default.as_json(*a)
      end
      if self.range
        config['minimum'] = self.range.first.as_json(*a)
        config['maximum'] = self.range.last.as_json(*a)
      end
      config['endianness'] = self.endianness.to_s
      config['required'] = self.required
      config['format_string'] = self.format_string if self.format_string
      if self.units
        config['units'] = self.units
        config['units_full'] = self.units_full
      end
      config['overflow'] = self.overflow.to_s
      if @states
        states = {}
        config['states'] = states
        @states.each do |state_name, state_value|
          state = {}
          states[state_name] = state
          state['value'] = state_value.as_json(*a)
          state['hazardous'] = @hazardous[state_name] if @hazardous and @hazardous[state_name]
          state['color'] = @state_colors[state_name].to_s if @state_colors and @state_colors[state_name]
        end
      end

      config['read_conversion'] = self.read_conversion.as_json(*a) if self.read_conversion
      config['write_conversion'] = self.write_conversion.as_json(*a) if self.write_conversion

      if self.limits
        if self.limits.values
          config['limits'] ||= {}
          config['limits']['persistence_setting'] = self.limits.persistence_setting
          config['limits']['enabled'] = true if self.limits.enabled
          self.limits.values.each do |limits_set, limits_values|
            limits = {}
            limits['red_low'] =  limits_values[0]
            limits['yellow_low'] = limits_values[1]
            limits['yellow_high'] = limits_values[2]
            limits['red_high'] = limits_values[3]
            limits['green_low'] = limits_values[4] if limits_values[4]
            limits['green_high'] = limits_values[5] if limits_values[5]
            config['limits'][limits_set] = limits
          end
        end
        config['limits_response'] = self.limits.response.as_json(*a) if self.limits.response
      end

      config['meta'] = @meta if @meta
      config
    end

    def self.from_json(hash)
      # Convert strings to symbols
      endianness = hash['endianness'] ? hash['endianness'].intern : nil
      data_type = hash['data_type'] ? hash['data_type'].intern : nil
      overflow = hash['overflow'] ? hash['overflow'].intern : nil
      item = PacketItem.new(hash['name'], hash['bit_offset'], hash['bit_size'],
        data_type, endianness, hash['array_size'], overflow)
      item.description = hash['description']
      item.id_value = hash['id_value']
      item.default = hash['default']
      item.range = (hash['minimum']..hash['maximum']) if hash['minimum'] && hash['maximum']
      item.required = hash['required']
      item.format_string = hash['format_string']
      item.units = hash['units']
      item.units_full = hash['units_full']
      if hash['states']
        item.states = {}
        item.hazardous = {}
        item.state_colors = {}
        hash['states'].each do |state_name, state|
          item.states[state_name] = state['value']
          item.hazardous[state_name] = state['hazardous']
          item.state_colors[state_name] = state['color'].to_sym if state['color']
        end
      end
      # Recreate OpenC3 built-in conversions
      if hash['read_conversion']
        begin
          item.read_conversion = OpenC3::const_get(hash['read_conversion']['class']).new(*hash['read_conversion']['params'])
        rescue => error
          Logger.instance.error "#{item.name} read_conversion of #{hash['read_conversion']} could not be instantiated due to #{error}"
        end
      end
      if hash['write_conversion']
        begin
          item.write_conversion = OpenC3::const_get(hash['write_conversion']['class']).new(*hash['write_conversion']['params'])
        rescue => error
          Logger.instance.error "#{item.name} write_conversion of #{hash['write_conversion']} could not be instantiated due to #{error}"
        end
      end

      if hash['limits']
        item.limits = PacketItemLimits.new
        # Delete these keys so the only ones left are limits sets
        item.limits.persistence_setting = hash['limits'].delete('persistence_setting')
        item.limits.enabled = true if hash['limits'].delete('enabled')
        values = {}
        hash['limits'].each do |set, items|
          values[set.to_sym] = [items['red_low'], items['yellow_low'], items['yellow_high'], items['red_high']]
          values[set.to_sym].concat([items['green_low'], items['green_high']]) if items['green_low'] && items['green_high']
        end
        item.limits.values = values
      end
      item.meta = hash['meta']
      item
    end

    protected

    def parameter_config
      if @id_value
        value = @id_value
        config = "  ID_PARAMETER "
      else
        value = @default
        config = "  PARAMETER "
      end
      config << "#{@name.to_s.quote_if_necessary} #{@bit_offset} #{@bit_size} #{@data_type} "

      if @data_type == :BLOCK || @data_type == :STRING
        unless value.is_printable?
          val_string = "0x" + value.simple_formatted
        else
          val_string = "\"#{value}\""
        end
      else
        first, last = calculate_range()
        config << "#{first} #{last} "
        val_string = value.to_s
      end
      config << "#{val_string} \"#{@description.to_s.gsub("\"", "'")}\""
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
  end
end
