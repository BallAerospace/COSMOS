# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/binary_accessor'
require 'cosmos/packets/structure_item'
require 'cosmos/ext/packet' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']

module Cosmos

  # Maintains knowledge of a raw binary structure. Uses structure_item to
  # create individual structure items which are read and written by
  # binary_accessor.
  class Structure

    # @return [Symbol] Default endianness for items in the structure. One of
    #   {BinaryAccessor::ENDIANNESS}
    attr_reader :default_endianness

    # @return [Hash] Items that make up the structure.
    #   Hash key is the item's name in uppercase
    attr_reader :items

    # @return [Array] Items sorted by bit_offset.
    attr_reader :sorted_items

    # @return [Integer] Defined length in bytes (not bits) of the structure
    attr_reader :defined_length

    # @return [Integer] Defined length in bits of the structure
    attr_reader :defined_length_bits

    # @return [Boolean] Flag indicating if the structure contains any variably
    #   sized items or not.
    attr_reader :fixed_size

    # @return [Boolean] Flag indicating if giving a buffer with less than
    #   required data size is allowed.
    attr_accessor :short_buffer_allowed

    if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
      # Used to force encoding
      ASCII_8BIT_STRING = "ASCII-8BIT".freeze

      # String providing a single 0 byte
      ZERO_STRING = "\000".freeze

      # Structure constructor
      #
      # @param default_endianness [Symbol] Must be one of
      #   {BinaryAccessor::ENDIANNESS}. By default it uses
      #   BinaryAccessor::HOST_ENDIANNESS to determine the endianness of the host platform.
      # @param buffer [String] Buffer used to store the structure
      # @param item_class [Class] Class used to instantiate new structure items.
      #   Must be StructureItem or one of its subclasses.
      def initialize(default_endianness = BinaryAccessor::HOST_ENDIANNESS, buffer = '', item_class = StructureItem)
        if (default_endianness == :BIG_ENDIAN) || (default_endianness == :LITTLE_ENDIAN)
          @default_endianness = default_endianness
          if buffer
            raise TypeError, "wrong argument type #{buffer.class} (expected String)" unless String === buffer
            @buffer = buffer.force_encoding(ASCII_8BIT_STRING)
          else
            @buffer = nil
          end
          @item_class = item_class
          @items = {}
          @sorted_items = []
          @defined_length = 0
          @defined_length_bits = 0
          @pos_bit_size = 0
          @neg_bit_size = 0
          @fixed_size = true
          @short_buffer_allowed = false
          @mutex = nil
        else
          raise(ArgumentError, "Unrecognized endianness: #{default_endianness} - Must be :BIG_ENDIAN or :LITTLE_ENDIAN")
        end
      end

      # Read an item in the structure
      #
      # @param item [StructureItem] Instance of StructureItem or one of its subclasses
      # @param value_type [Symbol] Not used. Subclasses should overload this
      #   parameter to check whether to perform conversions on the item.
      # @param buffer [String] The binary buffer to read the item from
      # @return Value based on the item definition. This could be a string, integer,
      #   float, or array of values.
      def read_item(item, value_type = :RAW, buffer = @buffer)
        return nil if item.data_type == :DERIVED

        if buffer
          if item.array_size
            return BinaryAccessor.read_array(item.bit_offset, item.bit_size, item.data_type, item.array_size, buffer, item.endianness)
          else
            return BinaryAccessor.read(item.bit_offset, item.bit_size, item.data_type, buffer, item.endianness)
          end
        else
          raise "No buffer given to read_item"
        end
      end

      # Get the length of the buffer used by the structure
      #
      # @return [Integer] Size of the buffer in bytes
      def length
        return @buffer.length if @buffer
        return 0
      end

      # Resize the buffer at least the defined length of the structure
      def resize_buffer
        if @buffer
          # Extend data size
          if @buffer.length < @defined_length
            @buffer << (ZERO_STRING * (@defined_length - @buffer.length))
          end
        end

        return self
      end
    end

    # Indicates if any items have been defined for this structure
    # @return [TrueClass or FalseClass]
    def defined?
      @sorted_items.length > 0
    end

    # Rename an existing item
    #
    # @param item_name [String] Name of the currently defined item
    # @param new_item_name [String] New name for the item
    def rename_item(item_name, new_item_name)
      item = get_item(item_name)
      item.name = new_item_name
      @items.delete(item_name)
      @items[new_item_name] = item
      # Since @sorted_items contains the actual item reference it is
      # updated when we set the item.name
      item
    end

    # Define an item in the structure. This creates a new instance of the
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
    # @return [StrutureItem] The struture item defined
    def define_item(name, bit_offset, bit_size, data_type, array_size = nil, endianness = @default_endianness, overflow = :ERROR)
      # Handle case-insensitive naming
      name_upcase = name.upcase

      # Create the item
      item = @item_class.new(name_upcase, bit_offset, bit_size, data_type, endianness, array_size, overflow)
      define(item)
    end

    # Adds the given item to the items hash. It also resizes the buffer to
    # accomodate the new item.
    #
    # @param item [StructureItem] The structure item to add
    # @return [StrutureItem] The struture item defined
    def define(item)
      # Handle Overwriting Existing Item
      if @items[item.name]
        item_index = nil
        @sorted_items.each_with_index do |sorted_item, index|
          if sorted_item.name == item.name
            item_index = index
            break
          end
        end
        @sorted_items.delete_at(item_index) if item_index < @sorted_items.length
      end

      # Add to Sorted Items
      unless @sorted_items.empty?
        last_item = @sorted_items[-1]
        @sorted_items << item
        # If the current item or last item have a negative offset then we have
        # to re-sort. We also re-sort if the current item is less than the last
        # item because we are inserting.
        if last_item.bit_offset <= 0 or item.bit_offset <= 0 or item.bit_offset < last_item.bit_offset
          @sorted_items = @sorted_items.sort
        end
      else
        @sorted_items << item
      end

      # Add to the overall hash of defined items
      @items[item.name] = item
      # Update fixed size knowledge
      @fixed_size = false if ((item.data_type != :DERIVED and item.bit_size <= 0) or (item.array_size and item.array_size <= 0))

      # Recalculate the overall defined length of the structure
      update_needed = false
      if item.bit_offset >= 0
        if item.bit_size > 0
          if item.array_size
            if item.array_size >= 0
              item_defined_length_bits = item.bit_offset + item.array_size
            else
              item_defined_length_bits = item.bit_offset
            end
          else
            item_defined_length_bits = item.bit_offset + item.bit_size
          end
          if item_defined_length_bits > @pos_bit_size
            @pos_bit_size = item_defined_length_bits
            update_needed = true
          end
        else
          if item.bit_offset > @pos_bit_size
            @pos_bit_size = item.bit_offset
            update_needed = true
          end
        end
      else
        if item.bit_offset.abs > @neg_bit_size
          @neg_bit_size = item.bit_offset.abs
          update_needed = true
        end
      end
      if update_needed
        @defined_length_bits = @pos_bit_size + @neg_bit_size
        @defined_length = @defined_length_bits / 8
        @defined_length += 1 if @defined_length_bits % 8 != 0
      end

      # Resize the buffer if necessary
      resize_buffer() if @buffer

      return item
    end

    # Define an item at the end of the structure. This creates a new instance of the
    # item_class as given in the constructor and adds it to the items hash. It
    # also resizes the buffer to accomodate the new item.
    #
    # @param name (see #define_item)
    # @param bit_size (see #define_item)
    # @param data_type (see #define_item)
    # @param array_size (see #define_item)
    # @param endianness (see #define_item)
    # @param overflow (see #define_item)
    # @return (see #define_item)
    def append_item(name, bit_size, data_type, array_size = nil, endianness = @default_endianness, overflow = :ERROR)
      raise ArgumentError, "Can't append an item after a variably sized item" if !@fixed_size
      if data_type == :DERIVED
        return define_item(name, 0, bit_size, data_type, array_size, endianness, overflow)
      else
        return define_item(name, @defined_length_bits, bit_size, data_type, array_size, endianness, overflow)
      end
    end

    # Adds an item at the end of the structure. It adds the item to the items
    # hash and resizes the buffer to accomodate the new item.
    #
    # @param item (see #define)
    # @return (see #define)
    def append(item)
      raise ArgumentError, "Can't append an item after a variably sized item" if !@fixed_size
      if item.data_type == :DERIVED
        item.bit_offset = 0
      else
        item.bit_offset = @defined_length_bits
      end
      return define(item)
    end

    # @param name [String] Name of the item to look up in the items Hash
    # @return [StructureItem] StructureItem or one of its subclasses
    def get_item(name)
      item = @items[name.upcase]
      raise ArgumentError, "Unknown item: #{name}" unless item
      return item
    end

    # @param item [#name] Instance of StructureItem or one of its subclasses.
    #   The name method will be used to look up the item and set it to the new instance.
    def set_item(item)
      if @items[item.name]
        @items[item.name] = item
      else
        raise ArgumentError, "Unknown item: #{item.name} - Ensure item name is uppercase"
      end
    end

    # Write a value to the buffer based on the item definition
    #
    # @param item [StructureItem] Instance of StructureItem or one of its subclasses
    # @param value [Object] Value based on the item definition. This could be
    #   a string, integer, float, or array of values.
    # @param value_type [Symbol] Not used. Subclasses should overload this
    #   parameter to check whether to perform conversions on the item.
    # @param buffer [String] The binary buffer to write the value to
    def write_item(item, value, value_type = :RAW, buffer = @buffer)
      if buffer
        if item.array_size
          BinaryAccessor.write_array(value, item.bit_offset, item.bit_size, item.data_type, item.array_size, buffer, item.endianness, item.overflow)
        else
          BinaryAccessor.write(value, item.bit_offset, item.bit_size, item.data_type, buffer, item.endianness, item.overflow)
        end
      else
        raise "No buffer given to write_item"
      end
    end

    # Read an item in the structure by name
    #
    # @param name [String] Name of an item to read
    # @param value_type [Symbol] Not used. Subclasses should overload this
    #   parameter to check whether to perform conversions on the item.
    # @param buffer [String] The binary buffer to read the item from
    # @return Value based on the item definition. This could be an integer,
    #   float, or array of values.
    def read(name, value_type = :RAW, buffer = @buffer)
      return read_item(get_item(name), value_type, buffer)
    end

    # Write an item in the structure by name
    #
    # @param name [Object] Name of the item to write
    # @param value [Object] Value based on the item definition. This could be
    #   a string, integer, float, or array of values.
    # @param value_type [Symbol] Not used. Subclasses should overload this
    #   parameter to check whether to perform conversions on the item.
    # @param buffer [String] The binary buffer to write the value to
    def write(name, value, value_type = :RAW, buffer = @buffer)
      write_item(get_item(name), value, value_type, buffer)
    end

    # Read all items in the structure into an array of arrays
    #   [[item name, item value], ...]
    #
    # @param value_type [Symbol] Not used. Subclasses should overload this
    #   parameter to check whether to perform conversions on the item.
    # @param buffer [String] The binary buffer to write the value to
    # @param top [Boolean] Indicates if this is a top level call for the mutex
    # @return [Array<Array>] Array of two element arrays containing the item
    #   name as element 0 and item value as element 1.
    def read_all(value_type = :RAW, buffer = @buffer, top = true)
      item_array = []
      synchronize_allow_reads(top) do
        @sorted_items.each {|item| item_array << [item.name, read_item(item, value_type, buffer)]}
      end
      return item_array
    end

    # Create a string that shows the name and value of each item in the structure
    #
    # @param value_type [Symbol] Not used. Subclasses should overload this
    #   parameter to check whether to perform conversions on the item.
    # @param indent [Integer] Amount to indent before printing the item name
    # @param buffer [String] The binary buffer to write the value to
    # @param ignored [Array<String>] List of items to ignore when building the string
    # @return [String] String formatted with all the item names and values
    def formatted(value_type = :RAW, indent = 0, buffer = @buffer, ignored = nil)
      indent_string = ' ' * indent
      string = ''
      synchronize_allow_reads(true) do
        @sorted_items.each do |item|
          next if ignored && ignored.include?(item.name)
          if (item.data_type != :BLOCK) ||
             (item.data_type == :BLOCK and value_type != :RAW and
              item.respond_to? :read_conversion and item.read_conversion)
            string << "#{indent_string}#{item.name}: #{read_item(item, value_type, buffer)}\n"
          else
            value = read_item(item, value_type, buffer)
            if String === value
              string << "#{indent_string}#{item.name}:\n"
              string << value.formatted(1, 16, ' ', indent + 2)
            else
              string << "#{indent_string}#{item.name}: #{value}\n"
            end
          end
        end
      end
      return string
    end

    # Get the buffer used by the structure. The current buffer is copied and
    # thus modifications to the returned buffer will have no effect on the
    # structure items.
    #
    # @param copy [TrueClass/FalseClass] Whether to copy the buffer
    # @return [String] Data buffer backing the structure
    def buffer(copy = true)
      if @buffer
        if copy
          return @buffer.dup
        else
          return @buffer
        end
      else
        return nil
      end
    end

    # Set the buffer to be used by the structure. The buffer is copied and thus
    # further modifications to the buffer have no effect on the structure
    # items.
    #
    # @param buffer [String] Buffer of data to back the stucture items
    def buffer=(buffer)
      synchronize() do
        internal_buffer_equals(buffer)
      end
    end

    # Make a light weight clone of this structure. This only creates a new buffer
    # of data. The defined structure items are the same.
    #
    # @return [Structure] A copy of the current structure with a new underlying
    #   buffer of data
    def clone
      structure = super()
      # Use instance_variable_set since we have overriden buffer= to do
      # additional work that isn't neccessary here
      structure.instance_variable_set("@buffer".freeze, @buffer.clone) if @buffer
      return structure
    end
    alias dup clone

    # Enable the ability to read and write item values as if they were methods
    # to the class
    def enable_method_missing
      extend(MethodMissing)
    end

    protected

    # Take the structure mutex to ensure the buffer does not change while you perform activities
    def synchronize
      @mutex ||= Mutex.new
      @mutex.synchronize {|| yield}
    end

    # Take the structure mutex to ensure the buffer does not change while you perform activities
    # This versions allows reads to happen if a top level function has already taken the mutex
    # @param top [Boolean] If true this will take the mutex and set an allow reads flag to allow
    #      lower level calls to go forward without getting the mutex
    def synchronize_allow_reads(top = false)
      @mutex_allow_reads ||= false
      @mutex ||= Mutex.new
      if top
        @mutex.synchronize do
          @mutex_allow_reads = Thread.current
          begin
            yield
          ensure
            @mutex_allow_reads = false
          end
        end
      else
        got_mutex = @mutex.try_lock
        if got_mutex
          begin
            yield
          ensure
            @mutex.unlock
          end
        elsif @mutex_allow_reads == Thread.current
          yield
        end
      end
    end

    module MethodMissing
      # Method missing provides reading/writing item values as if they were methods to the class
      def method_missing(name, value = nil)
        if @buffer
          if value
            # Strip off the equals sign before looking up the item
            return write(name.to_s[0..-2], value)
          else
            return read(name.to_s)
          end
        else
          raise "No buffer available for method_missing"
        end
      end
    end

    def internal_buffer_equals(buffer)
      raise ArgumentError, "Buffer class is #{buffer.class} but must be String" unless String === buffer
      @buffer = buffer.dup
      @buffer.force_encoding('ASCII-8BIT'.freeze)
      if @buffer.length != @defined_length
        if @buffer.length < @defined_length
          resize_buffer()
          raise "Buffer length less than defined length" unless @short_buffer_allowed
        elsif @fixed_size and @defined_length != 0
          raise "Buffer length greater than defined length"
        end
      end
    end

  end # class Structure

end # module Cosmos
