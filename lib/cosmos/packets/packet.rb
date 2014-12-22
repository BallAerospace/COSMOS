# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/structure'
require 'cosmos/packets/packet_item'
require 'cosmos/ext/packet'

module Cosmos

  # Adds features common to all COSMOS packets of data to the Structure class.
  # This includes the additional attributes listed below. The primary behavior
  # Packet adds is the ability to apply formatting to PacketItem values as well
  # as managing PacketItem's limit states.
  class Packet < Structure

    # @return [String] Name of the target this packet is associated with
    attr_reader :target_name

    # @return [String] Name of the packet
    attr_reader :packet_name

    # @return [String] Description of the packet
    attr_reader :description

    # @return [Time] Time at which the packet was received
    attr_reader :received_time

    # @return [Integer] Number of times the packet has been received
    attr_reader :received_count

    # @return [Boolean] Flag indicating if the packet is hazardous (typically for commands)
    attr_accessor :hazardous

    # @return [String] Description of why the packet is hazardous
    attr_reader :hazardous_description

    # Containst the values given by the user for a command (distinguished from defaults)
    # These values should be used within command conversions if present because the order
    # that values are written into the actual packet can vary
    # @return [Hash<Item Name, Value>] Given values when constructing the packet
    attr_reader :given_values

    # @return [Boolean] Flag indicating if the packet is stale (hasn't been received recently)
    attr_reader :stale

    # @return [Boolean] Whether or not this is a 'raw' packet
    attr_accessor :raw

    # @return [Boolean] Whether or not this is a 'hidden' packet
    attr_accessor :hidden

    # @return [Boolean] Whether or not this is a 'disabled' packet
    attr_accessor :disabled

    # @return [Boolean] Whether or not messages should be printed for this packet
    attr_accessor :messages_disabled

    # Valid format types
    VALUE_TYPES = [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS]

    # Creates a new packet by initalizing the attributes.
    #
    # @param target_name [String] Name of the target this packet is associated with
    # @param packet_name [String] Name of the packet
    # @param default_endianness [Symbol] One of {BinaryAccessor::ENDIANNESS}
    # @param description [String] Description of the packet
    # @param buffer [String] String buffer to hold the packet data
    # @param item_class [Class] Class used to instantiate items (Must be a
    #   subclass of PacketItem)
    # def initialize(target_name, packet_name, default_endianness = :BIG_ENDIAN, description = nil, buffer = '', item_class = PacketItem)

    # (see Structure#buffer=)
    def buffer=(buffer)
      synchronize() do
        begin
          internal_buffer_equals(buffer)
        rescue RuntimeError
          Logger.instance.error "#{@target_name} #{@packet_name} received with actual packet length of #{buffer.length} but defined length of #{@defined_length}"
        end
        @read_conversion_cache.clear if @read_conversion_cache
        process()
      end
    end

    # Sets the target name this packet is associated with. Unidentified packets
    # will have target name set to nil.
    #
    # @param target_name [String] Name of the target this packet is associated with
    # def target_name=(target_name)

    # Sets the packet name. Unidentified packets will have packet name set to
    # nil.
    #
    # @param packet_name [String] Name of the packet
    # def packet_name=(packet_name)

    # Sets the description of the packet
    #
    # @param description [String] Description of the packet
    # def description=(description)

    # Sets the received time of the packet
    #
    # @param received_time [Time] Time this packet was received
    # def received_time=(received_time)

    # Sets the received time of the packet (without cloning)
    #
    # @param received_time [Time] Time this packet was received
    def set_received_time_fast(received_time)
      @received_time = received_time
      @received_time.freeze if @received_time
    end

    # Sets the received count of the packet
    #
    # @param received_count [Integer] Number of times this packet has been
    #   received
    # def received_count=(received_count)

    # Sets the hazardous description of the packet
    #
    # @param hazardous_description [String] Hazardous description of the packet
    def hazardous_description=(hazardous_description)
      if hazardous_description
        raise ArgumentError, "hazardous_description must be a String but is a #{hazardous_description.class}" unless String === hazardous_description
        @hazardous_description = hazardous_description.clone.freeze
      else
        @hazardous_description = nil
      end
    end

    # Saves a hash of the values given by a user when constructing a command
    #
    # @param given_values [Hash<Item Name, Value>] Hash of given command parameters
    def given_values=(given_values)
      if given_values
        raise ArgumentError, "given_values must be a Hash but is a #{given_values.class}" unless Hash === given_values
        @given_values = given_values.clone
      else
        @given_values = nil
      end
    end

    # Sets the callback object called when a limits state changes
    #
    # @param limits_change_callback [#call] Object must respond to the call
    #   method and take the following arguments: packet (Packet), item (PacketItem),
    #   old_limits_state (Symbol), item_value (Object), log_change (Boolean). The
    #   current item state can be found by querying the item object:
    #   item.limits.state.
    def limits_change_callback=(limits_change_callback)
      if limits_change_callback
        raise ArgumentError, "limits_change_callback must respond to call" unless limits_change_callback.respond_to?(:call)
        @limits_change_callback = limits_change_callback
      else
        @limits_change_callback = nil
      end
    end

    # Id items are used by the identify? method to determine if a raw buffer of
    # data represents this packet.
    # @return [Array<PacketItem>] Packet item identifiers
    def id_items
      @id_items ||= []
    end

    # @return [Array<PacketItem>] All items with defined limits
    def limits_items
      @limits_items ||= []
    end

    # @return [Hash] Hash of processors associated with this packet
    def processors
      @processors ||= {}
    end

    # Returns packet specific metadata
    # @return [Hash<Meta Name, Meta Values>]
    def meta
      @meta ||= {}
    end

    # Indicates if the packet has been identified
    # @return [TrueClass or FalseClass]
    def identified?
      !@target_name.nil? && !@packet_name.nil?
    end

    # Define an item in the packet. This creates a new instance of the
    # item_class as given in the constructor and adds it to the items hash. It
    # also resizes the buffer to accomodate the new item.
    #
    # @param name [String] Name of the item. Used by the items hash to retrieve
    #   the item.
    # @param bit_offset [Integer] Bit offset of the item in the raw buffer
    # @param bit_size [Integer] Bit size of the item in the raw buffer
    # @param data_type [Symbol] Type of data contained by the item. This is
    #   dependant on the item_class but by default see StructureItem.
    # @param array_size [Integer] Set to a non nil value if the item is to
    #   represented as an array.
    # @param endianness [Symbol] Endianness of this item. By default the
    #   endianness as set in the constructure is used.
    # @param overflow [Symbol] How to handle value overflows. This is
    #   dependant on the item_class but by default see StructureItem.
    # @param format_string [String] String to pass to Kernel#sprintf
    # @param read_conversion [Conversion] Conversion to apply when reading the
    #   item from the packet buffer
    # @param write_conversion [Conversion] Conversion to apply before writing
    #   the item to the packet buffer
    # @param id_value [Object] Set to something other than nil to indicate that
    #   this item should be used to identify a buffer as this packet. The
    #   id_value should make sense according to the data_type.
    def define_item(name, bit_offset, bit_size, data_type, array_size = nil, endianness = @default_endianness, overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
      item = super(name, bit_offset, bit_size, data_type, array_size, endianness, overflow)
      packet_define_item(item, format_string, read_conversion, write_conversion, id_value)
    end

    # Define an item at the end of the packet. This creates a new instance of the
    # item_class as given in the constructor and adds it to the items hash. It
    # also resizes the buffer to accomodate the new item.
    #
    # @param name (see #define_item)
    # @param bit_size (see #define_item)
    # @param data_type (see #define_item)
    # @param array_size (see #define_item)
    # @param endianness (see #define_item)
    # @param overflow (see #define_item)
    # @param format_string (see #define_item)
    # @param read_conversion (see #define_item)
    # @param write_conversion (see #define_item)
    # @param id_value (see #define_item)
    def append_item(name, bit_size, data_type, array_size = nil, endianness = @default_endianness, overflow = :ERROR, format_string = nil, read_conversion = nil, write_conversion = nil, id_value = nil)
      item = super(name, bit_size, data_type, array_size, endianness, overflow)
      packet_define_item(item, format_string, read_conversion, write_conversion, id_value)
    end

    # (see Structure#get_item)
    def get_item(name)
      super(name)
    rescue ArgumentError
      raise "Packet item '#{@target_name} #{@packet_name} #{name.upcase}' does not exist"
    end

    # Read an item in the packet
    #
    # @param item [PacketItem] Instance of PacketItem or one of its subclasses
    # @param value_type [Symbol] How to convert the item before returning it.
    #   Must be one of {VALUE_TYPES}
    # @param buffer (see Structure#read_item)
    # @return The value. :FORMATTED and :WITH_UNITS values are always returned
    #   as Strings. :RAW values will match their data_type. :CONVERTED values
    #   can be any type.
    def read_item(item, value_type = :CONVERTED, buffer = @buffer)
      value = super(item, :RAW, buffer)
      case value_type
      when :RAW
        # Done above
      when :CONVERTED, :FORMATTED, :WITH_UNITS
        if item.read_conversion
          use_cache = buffer.equal?(@buffer)
          if use_cache and @read_conversion_cache and @read_conversion_cache[item]
            value = @read_conversion_cache[item]
          else
            if item.array_size
              value.map! do |val, index|
                item.read_conversion.call(val, self, buffer)
              end
            else
              value = item.read_conversion.call(value, self, buffer)
            end
            @read_conversion_cache ||= {}
            @read_conversion_cache[item] = value if use_cache
          end
        end

        # Convert from value to state if possible
        if item.states
          if item.array_size
            value = value.map do |val, index|
              if item.states.key(val)
                item.states.key(val)
              else
                apply_format_string_and_units(item, val, value_type)
              end
            end
          else
            state_value = item.states.key(value)
            if state_value
              value = state_value
            else
              value = apply_format_string_and_units(item, value, value_type)
            end
          end
        else
          if item.array_size
            value = value.map do |val, index|
              apply_format_string_and_units(item, val, value_type)
            end
          else
            value = apply_format_string_and_units(item, value, value_type)
          end
        end
      else
        raise ArgumentError, "Unknown value type on read: #{value_type}"
      end
      return value
    end

    # Write an item in the packet
    #
    # @param item [PacketItem] Instance of PacketItem or one of its subclasses
    # @param value (see Structure#write_item)
    # @param value_type (see #read_item)
    # @param buffer (see Structure#write_item)
    def write_item(item, value, value_type = :CONVERTED, buffer = @buffer)
      @read_conversion_cache.clear if @read_conversion_cache
      case value_type
      when :RAW
        super(item, value, value_type, buffer)
      when :CONVERTED
        if item.states
          # Convert from state to value if possible
          state_value = item.states[value.to_s.upcase]
          value = state_value if state_value
        end
        if item.write_conversion
          value = item.write_conversion.call(value, self, buffer)
        else
          raise "Cannot write DERIVED item without a write conversion" if item.data_type == :DERIVED
        end
        begin
          super(item, value, :RAW, buffer) unless item.data_type == :DERIVED
        rescue ArgumentError => err
          if item.states and String === value and err.message =~ /invalid value for/
            raise "Unknown state #{value} for #{item.name}"
          else
            raise err
          end
        end
      when :FORMATTED, :WITH_UNITS
        raise ArgumentError, "Invalid value type on write: #{value_type}"
      else
        raise ArgumentError, "Unknown value type on write: #{value_type}"
      end
    end

    # Read an item in the packet by name
    #
    # @param name [String] Name of the item to read
    # @param value_type (see #read_item)
    # @param buffer (see #read_item)
    # @return (see #read_item)
    def read(name, value_type = :CONVERTED, buffer = @buffer)
      return super(name, value_type, buffer)
    end

    # Write an item in the packet by name
    #
    # @param name [String] Name of the item to write
    # @param value (see #write_item)
    # @param value_type (see #write_item)
    # @param buffer (see #write_item)
    def write(name, value, value_type = :CONVERTED, buffer = @buffer)
      super(name, value, value_type, buffer)
    end

    # Read all items in the packet into an array of arrays
    #   [[item name, item value], ...]
    #
    # @param value_type (see #read_item)
    # @param buffer (see Structure#read_all)
    # @return (see Structure#read_all)
    def read_all(value_type = :CONVERTED, buffer = @buffer)
      return super(value_type, buffer)
    end

    # Read all items in the packet into an array of arrays
    #   [[item name, item value], [item limits state], ...]
    #
    # @param value_type (see #read_all)
    # @param buffer (see #read_all)
    # @return [Array<String, Object, Symbol|nil>] Returns an Array consisting
    #   of [item name, item value, item limits state] where the item limits
    #   state can be one of {Cosmos::Limits::LIMITS_STATES}
    def read_all_with_limits_states(value_type = :CONVERTED, buffer = @buffer)
      return read_all(value_type, buffer).map! do |array|
        array << @items[array[0]].limits.state
      end
    end

    # Create a string that shows the name and value of each item in the packet
    #
    # @param value_type (see #read_item)
    # @param indent (see Structure#formatted)
    # @param buffer (see Structure#formatted)
    # @return (see Structure#formatted)
    def formatted(value_type = :CONVERTED, indent = 0, buffer = @buffer)
      return super(value_type, indent, buffer)
    end

    # Tries to identify if a buffer represents the currently defined packet. It
    # does this by iterating over all the packet items that were created with
    # an ID value and checking whether that ID value is present at the correct
    # location in the buffer.
    #
    # Incorrectly sized buffers will still positively identify if there is
    # enough data to match the ID values. This is to allow incorrectly sized
    # packets to still be processed as well as possible given the incorrectly
    # sized data.
    #
    # @param buffer [String] Raw buffer of binary data
    # @return [Boolean] Whether or not the buffer of data is this packet
    # def identify?(buffer)

    # Restore all items in the packet to their default value
    #
    # @param buffer [String] Raw buffer of binary data
    def restore_defaults(buffer = @buffer)
      @sorted_items.each do |item|
        write_item(item, item.default, :CONVERTED, buffer)
      end
    end

    # Enable limits on an item by name
    #
    # @param name [String] Name of the item to enable limits
    def enable_limits(name)
      get_item(name).limits.enabled = true
    end

    # Disable limits on an item by name
    #
    # @param name [String] Name of the item to disable limits
    def disable_limits(name)
      item = get_item(name)
      item.limits.enabled = false
      unless item.limits.state == :STALE
        old_limits_state = item.limits.state
        item.limits.state = nil
        @limits_change_callback.call(self, item, old_limits_state, nil, false) if @limits_change_callback
      end
    end

    # Force the packet to update its knowledge of items with limits. This is an
    # optimization so we don't have to iterate through all the items when
    # checking for limits.
    def update_limits_items_cache
      # Collect only the items who have limits values or states and then
      # compact the array to remove all the nil values
      @limits_items = @sorted_items.collect do |item|
        item if item.limits.values || item.state_colors
      end
      @limits_items.compact!
    end

    # Return an array of arrays indicating all items in the packet that are out of limits
    #   [[target name, packet name, item name, item limits state], ...]
    #
    # @return [Array<Array<String, String, String, Symbol>>]
    def out_of_limits
      items = []
      return items unless @limits_items
      @limits_items.each do |item|
        if (item.limits.enabled && item.limits.state &&
          PacketItemLimits::OUT_OF_LIMITS_STATES.include?(item.limits.state))
          items << [@target_name, @packet_name, item.name, item.limits.state]
        end
      end
      return items
    end

    # Set the limits state for all items to the given state
    #
    # @param state [Symbol] Must be one of PacketItemLimits::LIMITS_STATES
    def set_all_limits_states(state)
      @sorted_items.each {|item| item.limits.state = state}
    end

    # Check all the items in the packet against their defined limits. Update
    # their internal limits state and persistence and call the
    # limits_change_callback as necessary.
    #
    # @param limits_set [Symbol] Which limits set to check the item values
    #   against.
    # @param ignore_persistence [Boolean] Whether to ignore persistence when
    #   checking for out of limits
    def check_limits(limits_set = :DEFAULT, ignore_persistence = false)
      # If check_limits is being called, then a new packet has arrived and
      # this packet is no longer stale
      if @stale
        @stale = false
        set_all_limits_states(nil)
      end

      return unless @limits_items
      @limits_items.each do |item|
        # Verify limits monitoring is enabled for this item
        if item.limits.enabled
          value = read_item(item)

          # Handle state monitoring and value monitoring differently
          if item.states
            handle_limits_states(item, value)
          elsif item.limits.values
            handle_limits_values(item, value, limits_set, ignore_persistence)
          end
        end
      end
    end

    # Sets the overall packet stale state to true and sets each packet item
    # limits state to :STALE.
    def set_stale
      @stale = true
      set_all_limits_states(:STALE)
    end

    # Reset temporary packet data
    # This includes packet received time, received count, and processor state
    def reset
      @received_time = nil
      @received_count = 0
      @read_conversion_cache.clear if @read_conversion_cache
      return unless @processors
      @processors.each do |processor_name, processor|
        processor.reset
      end
    end

    # Make a light weight clone of this packet. This only creates a new buffer
    # of data and clones the processors. The defined packet items are the same.
    #
    # @return [Packet] A copy of the current packet with a new underlying
    #   buffer of data and processors
    def clone
      packet = super()
      if packet.instance_variable_get("@processors")
        packet.processors.each do |processor_name, processor|
          packet.processors[processor_name] = processor.clone
        end
      end
      packet
    end
    alias dup clone

    protected

    # Performs packet specific processing on the packet.  Intended to only be run once for each packet received
    def process(buffer = @buffer)
      return unless @processors
      @processors.each do |processor_name, processor|
        processor.call(self, buffer)
      end
    end

    def handle_limits_states(item, value)
      # Retrieve limits state for the given value
      limits_state = item.state_colors[value]

      if item.limits.state != limits_state # PacketItemLimits state has changed
        # Save old limits state
        old_limits_state = item.limits.state
        # Update to new limits state
        item.limits.state = limits_state

        if old_limits_state == nil # Changing from nil
          if limits_state != :GREEN && limits_state != :BLUE # Warnings are needed
            @limits_change_callback.call(self, item, old_limits_state, value, true) if @limits_change_callback
          end
        else # Changing from a state other than nil so always call the callback
          if @limits_change_callback
            if item.limits.state.nil?
              @limits_change_callback.call(self, item, old_limits_state, value, false)
            else
              @limits_change_callback.call(self, item, old_limits_state, value, true)
            end
          end
        end
      end
    end

    def handle_limits_values(item, value, limits_set, ignore_persistence)
      # Retrieve limits settings for the specified limits_set
      limits = item.limits.values[limits_set]

      # Use the default limits set if limits aren't specified for the
      # particular limits set
      limits = item.limits.values[:DEFAULT] unless limits

      # Extract limits from array
      red_low     = limits[0]
      yellow_low  = limits[1]
      yellow_high = limits[2]
      red_high    = limits[3]
      green_low   = limits[4]
      green_high  = limits[5]
      limits_state = nil

      # Determine the limits_state based on the limits values and the current
      # value of the item
      if (value > yellow_low)
        if (value < yellow_high)
          if green_low
            if value < green_high
              if value > green_low
                limits_state = :BLUE
              else
                limits_state = :GREEN_LOW
              end
            else
              limits_state = :GREEN_HIGH
            end
          else
            limits_state = :GREEN
          end
        elsif (value < red_high)
          limits_state = :YELLOW_HIGH
        else
          limits_state = :RED_HIGH
        end
      else # value <= yellow_low
        if (value > red_low)
          limits_state = :YELLOW_LOW
        else
          limits_state = :RED_LOW
        end
      end

      if item.limits.state != limits_state # limits state has changed
        # Save old limits state
        old_limits_state = item.limits.state

        if old_limits_state == nil # Changing from nil
          # Persistence is ignored when changing from nil.
          # Immediately update limits state
          item.limits.state = limits_state

          if @limits_change_callback && PacketItemLimits::OUT_OF_LIMITS_STATES.include?(limits_state)
            @limits_change_callback.call(self, item, old_limits_state, value, true)
          end

          # Clear the persistence since we've entered a new state
          item.limits.persistence_count = 0

        else # changing from a current state (:GREEN, :YELLOW, :RED, etc)
          item.limits.persistence_count += 1

          # Check for item to achieve its persistence which means we
          # have to update the state and call the callback
          if (item.limits.persistence_count >= item.limits.persistence_setting) or ignore_persistence
            item.limits.state = limits_state

            # Additional actions for limits change
            @limits_change_callback.call(self, item, old_limits_state, value, true) if @limits_change_callback

            # Clear Persistence since we've entered a new state
            item.limits.persistence_count = 0
          end
        end
      end # limits state has not changed
    end

    def apply_format_string_and_units(item, value, value_type)
      if value_type == :FORMATTED or value_type == :WITH_UNITS
        if item.format_string && value
          value = sprintf(item.format_string, value)
        else
          value = value.to_s
        end
      end
      value << ' ' << item.units if value_type == :WITH_UNITS and item.units
      value
    end

    def packet_define_item(item, format_string, read_conversion, write_conversion, id_value)
      item.format_string = format_string
      item.read_conversion = read_conversion
      item.write_conversion = write_conversion

      # Change id_value to the correct type
      if id_value
        item.id_value = id_value
        @id_items ||= []
        @id_items << item
      end

      item
    end
  end # class Packet

end # module Cosmos
