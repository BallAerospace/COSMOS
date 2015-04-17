# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the BinaryAccessor class.
# This class allows for easy reading and writing of binary data in Ruby

require 'cosmos/ext/packet'

module Cosmos

  # Provides methods for binary reading and writing
  class BinaryAccessor

    # Constants for ruby packing directives
    PACK_8_BIT_INT = 'c'
    PACK_NATIVE_16_BIT_INT = 's'
    PACK_LITTLE_ENDIAN_16_BIT_UINT = 'v'
    PACK_BIG_ENDIAN_16_BIT_UINT = 'n'
    PACK_NATIVE_32_BIT_INT = 'l'
    PACK_NATIVE_32_BIT_UINT = 'L'
    PACK_NATIVE_64_BIT_INT = 'q'
    PACK_NATIVE_64_BIT_UINT = 'Q'
    PACK_LITTLE_ENDIAN_32_BIT_UINT = 'V'
    PACK_BIG_ENDIAN_32_BIT_UINT = 'N'
    PACK_LITTLE_ENDIAN_32_BIT_FLOAT = 'e'
    PACK_LITTLE_ENDIAN_64_BIT_FLOAT = 'E'
    PACK_BIG_ENDIAN_32_BIT_FLOAT = 'g'
    PACK_BIG_ENDIAN_64_BIT_FLOAT = 'G'
    PACK_NULL_TERMINATED_STRING = 'Z*'
    PACK_BLOCK = 'a*'
    PACK_8_BIT_INT_ARRAY = 'c*'
    PACK_8_BIT_UINT_ARRAY = 'C*'
    PACK_NATIVE_16_BIT_INT_ARRAY = 's*'
    PACK_BIG_ENDIAN_16_BIT_UINT_ARRAY = 'n*'
    PACK_LITTLE_ENDIAN_16_BIT_UINT_ARRAY = 'v*'
    PACK_NATIVE_32_BIT_INT_ARRAY = 'l*'
    PACK_BIG_ENDIAN_32_BIT_UINT_ARRAY = 'N*'
    PACK_LITTLE_ENDIAN_32_BIT_UINT_ARRAY = 'V*'
    PACK_NATIVE_64_BIT_INT_ARRAY = 'q*'
    PACK_NATIVE_64_BIT_UINT_ARRAY = 'Q*'
    PACK_LITTLE_ENDIAN_32_BIT_FLOAT_ARRAY = 'e*'
    PACK_LITTLE_ENDIAN_64_BIT_FLOAT_ARRAY = 'E*'
    PACK_BIG_ENDIAN_32_BIT_FLOAT_ARRAY = 'g*'
    PACK_BIG_ENDIAN_64_BIT_FLOAT_ARRAY = 'G*'

    # Additional Constants
    ZERO_STRING = "\000"

    # Valid data types
    DATA_TYPES = [:INT, :UINT, :FLOAT, :STRING, :BLOCK]

    # Valid overflow types
    OVERFLOW_TYPES = [:TRUNCATE, :SATURATE, :ERROR, :ERROR_ALLOW_HEX]

    protected

    # Determines the endianness of the host running this code
    #
    # This method is protected to force the use of the constant
    # HOST_ENDIANNESS rather than this method
    #
    # @return [Symbol] :BIG_ENDIAN or :LITTLE_ENDIAN
    def self.get_host_endianness
      value = 0x01020304
      packed = [value].pack(PACK_NATIVE_32_BIT_UINT)
      unpacked = packed.unpack(PACK_LITTLE_ENDIAN_32_BIT_UINT)[0]
      if unpacked == value
        :LITTLE_ENDIAN
      else
        :BIG_ENDIAN
      end
    end

    def self.raise_buffer_error(read_write, buffer, data_type, given_bit_offset, given_bit_size)
      raise ArgumentError, "#{buffer.length} byte buffer insufficient to #{read_write} #{data_type} at bit_offset #{given_bit_offset} with bit_size #{given_bit_size}"
    end

    public

    # Store the host endianness so that it only has to be determined once
    HOST_ENDIANNESS = get_host_endianness()
    # Valid endianess
    ENDIANNESS = [:BIG_ENDIAN, :LITTLE_ENDIAN]

    # Reads binary data of any data type from a buffer
    #
    # @param bit_offset [Integer] Bit offset to the start of the item. A
    #   negative number means to offset from the end of the buffer.
    # @param bit_size [Integer] Size of the item in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param buffer [String] Binary string buffer to read from
    # @param endianness [Symbol] {ENDIANNESS}
    # @return [Integer] value read from the buffer
    # def self.read(bit_offset, bit_size, data_type, buffer, endianness)

    # Writes binary data of any data type to a buffer
    #
    # @param value [Varies] Value to write into the buffer
    # @param bit_offset [Integer] Bit offset to the start of the item. A
    #   negative number means to offset from the end of the buffer.
    # @param bit_size [Integer] Size of the item in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param buffer [String] Binary string buffer to write to
    # @param endianness [Symbol] {ENDIANNESS}
    # @param overflow [Symbol] {OVERFLOW_TYPES}
    # @return [Integer] value passed in as a parameter
    # def self.write(value, bit_offset, bit_size, data_type, buffer, endianness, overflow)

    # Reads an array of binary data of any data type from a buffer
    #
    # @param bit_offset [Integer] Bit offset to the start of the array. A
    #   negative number means to offset from the end of the buffer.
    # @param bit_size [Integer] Size of each item in the array in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param array_size [Integer] Size in bits of the array. 0 or negative means
    #   fill the array with as many bit_size number of items that exist (negative
    #   means excluding the final X number of bits).
    # @param buffer [String] Binary string buffer to read from
    # @param endianness [Symbol] {ENDIANNESS}
    # @return [Array] Array created from reading the buffer
    def self.read_array(bit_offset, bit_size, data_type, array_size, buffer, endianness)
      # Save given values of bit offset, bit size, and array_size
      given_bit_offset = bit_offset
      given_bit_size = bit_size
      given_array_size = array_size

      # Handle negative and zero bit sizes
      raise ArgumentError, "bit_size #{given_bit_size} must be positive for arrays" if bit_size <= 0

      # Handle negative bit offsets
      if bit_offset < 0
        bit_offset = ((buffer.length * 8) + bit_offset)
        raise_buffer_error(:read, buffer, data_type, given_bit_offset, given_bit_size) if bit_offset < 0
      end

      # Handle negative and zero array sizes
      if array_size <= 0
        if given_bit_offset < 0
          raise ArgumentError, "negative or zero array_size (#{given_array_size}) cannot be given with negative bit_offset (#{given_bit_offset})"
        else
          array_size = ((buffer.length * 8) - bit_offset + array_size)
          if array_size == 0
            return []
          elsif array_size < 0
            raise_buffer_error(:read, buffer, data_type, given_bit_offset, given_bit_size)
          end
        end
      end

      # Calculate number of items in the array
      # If there is a remainder then we have a problem
      raise ArgumentError, "array_size #{given_array_size} not a multiple of bit_size #{given_bit_size}" if array_size % bit_size != 0
      num_items = array_size / bit_size

      # Define bounds of string to access this item
      lower_bound = bit_offset / 8
      upper_bound = (bit_offset + array_size - 1) / 8

      # Check for byte alignment
      byte_aligned = ((bit_offset % 8) == 0)

      case data_type
      when :STRING, :BLOCK
        #######################################
        # Handle :STRING and :BLOCK data types
        #######################################

        if byte_aligned
          value = []
          num_items.times do
            value << self.read(bit_offset, bit_size, data_type, buffer, endianness)
            bit_offset += bit_size
          end
        else
          raise ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}"
        end

      when :INT, :UINT
        ###################################
        # Handle :INT and :UINT data types
        ###################################

        if byte_aligned and (bit_size == 8 or bit_size == 16 or bit_size == 32 or bit_size == 64)
          ###########################################################
          # Handle byte-aligned 8, 16, 32, and 64 bit :INT and :UINT
          ###########################################################

          case bit_size
          when 8
            if data_type == :INT
              value = buffer[lower_bound..upper_bound].unpack(PACK_8_BIT_INT_ARRAY)
            else # data_type == :UINT
              value = buffer[lower_bound..upper_bound].unpack(PACK_8_BIT_UINT_ARRAY)
            end

          when 16
            if data_type == :INT
              if endianness == HOST_ENDIANNESS
                value = buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_16_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                temp = self.byte_swap_buffer(buffer[lower_bound..upper_bound], 2)
                value = temp.to_s.unpack(PACK_NATIVE_16_BIT_INT_ARRAY)
              end
            else # data_type == :UINT
              if endianness == :BIG_ENDIAN
                value = buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_16_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                value = buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_16_BIT_UINT_ARRAY)
              end
            end

          when 32
            if data_type == :INT
              if endianness == HOST_ENDIANNESS
                value = buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_32_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                temp = self.byte_swap_buffer(buffer[lower_bound..upper_bound], 4)
                value = temp.to_s.unpack(PACK_NATIVE_32_BIT_INT_ARRAY)
              end
            else # data_type == :UINT
              if endianness == :BIG_ENDIAN
                value = buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_32_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                value = buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_32_BIT_UINT_ARRAY)
              end
            end

          when 64
            if data_type == :INT
              if endianness == HOST_ENDIANNESS
                value = buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_64_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                temp = self.byte_swap_buffer(buffer[lower_bound..upper_bound], 8)
                value = temp.to_s.unpack(PACK_NATIVE_64_BIT_INT_ARRAY)
              end
            else # data_type == :UINT
              if endianness == HOST_ENDIANNESS
                value = buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_64_BIT_UINT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                temp = self.byte_swap_buffer(buffer[lower_bound..upper_bound], 8)
                value = temp.to_s.unpack(PACK_NATIVE_64_BIT_UINT_ARRAY)
              end
            end
          end

        else
          ##################################
          # Handle :INT and :UINT Bitfields
          ##################################
          raise ArgumentError, "read_array does not support little endian bit fields with bit_size greater than 1-bit" if endianness == :LITTLE_ENDIAN and bit_size > 1

          value = []
          num_items.times do
            value << self.read(bit_offset, bit_size, data_type, buffer, endianness)
            bit_offset += bit_size
          end
        end

      when :FLOAT
        ##########################
        # Handle :FLOAT data type
        ##########################

        if byte_aligned
          case bit_size
          when 32
            if endianness == :BIG_ENDIAN
              value = buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_32_BIT_FLOAT_ARRAY)
            else # endianness == :LITTLE_ENDIAN
              value = buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_32_BIT_FLOAT_ARRAY)
            end

          when 64
            if endianness == :BIG_ENDIAN
              value = buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_64_BIT_FLOAT_ARRAY)
            else # endianness == :LITTLE_ENDIAN
              value = buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_64_BIT_FLOAT_ARRAY)
            end

          else
            raise ArgumentError, "bit_size is #{given_bit_size} but must be 32 or 64 for data_type #{data_type}"
          end

        else
          raise ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}"
        end

      else
        ############################
        # Handle Unknown data types
        ############################

        raise ArgumentError, "data_type #{data_type} is not recognized"
      end

      value
    end # def read_array

    # Writes an array of binary data of any data type to a buffer
    #
    # @param values [Array] Values to write into the buffer
    # @param bit_offset [Integer] Bit offset to the start of the array. A
    #   negative number means to offset from the end of the buffer.
    # @param bit_size [Integer] Size of each item in the array in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param array_size [Integer] Size in bits of the array as represented in the buffer.
    #   Size 0 means to fill the buffer with as many bit_size number of items that exist
    #   (negative means excluding the final X number of bits).
    # @param buffer [String] Binary string buffer to write to
    # @param endianness [Symbol] {ENDIANNESS}
    # @return [Array] values passed in as a parameter
    def self.write_array(values, bit_offset, bit_size, data_type, array_size, buffer, endianness, overflow)
      # Save given values of bit offset, bit size, and array_size
      given_bit_offset = bit_offset
      given_bit_size = bit_size
      given_array_size = array_size

      # Verify an array was given
      raise ArgumentError, "values must be an Array type class is #{values.class}" unless values.kind_of? Array

      # Handle negative and zero bit sizes
      raise ArgumentError, "bit_size #{given_bit_size} must be positive for arrays" if bit_size <= 0

      # Handle negative bit offsets
      if bit_offset < 0
        bit_offset = ((buffer.length * 8) + bit_offset)
        raise_buffer_error(:write, buffer, data_type, given_bit_offset, given_bit_size) if bit_offset < 0
      end

      # Handle negative and zero array sizes
      if array_size <= 0
        if given_bit_offset < 0
          raise ArgumentError, "negative or zero array_size (#{given_array_size}) cannot be given with negative bit_offset (#{given_bit_offset})"
        else
          end_bytes = -(given_array_size / 8)
          lower_bound = bit_offset / 8
          upper_bound = (bit_offset + (bit_size * values.length) - 1) / 8
          old_upper_bound = buffer.length - 1 - end_bytes

          if upper_bound < old_upper_bound
            # Remove extra bytes from old buffer
            buffer[(upper_bound + 1)..old_upper_bound] = ''
          elsif upper_bound > old_upper_bound
            # Grow buffer and preserve bytes at end of buffer if necesssary
            buffer_length = buffer.length
            diff = upper_bound - old_upper_bound
            buffer << ZERO_STRING * diff
            if end_bytes > 0
              buffer[(upper_bound + 1)..(buffer.length - 1)] = buffer[(old_upper_bound + 1)..(buffer_length - 1)]
            end
          end

          array_size = ((buffer.length * 8) - bit_offset + array_size)
        end
      end

      # Get data bounds for this array
      lower_bound = bit_offset / 8
      upper_bound = (bit_offset + array_size - 1) / 8
      num_bytes   = upper_bound - lower_bound + 1

      # Check for byte alignment
      byte_aligned = ((bit_offset % 8) == 0)

      # Calculate the number of writes
      num_writes = array_size / bit_size
      # Check for a negative array_size and adjust the number of writes
      # to simply be the number of values in the passed in array
      if given_array_size <= 0
        num_writes = values.length
      end

      # Ensure the buffer has enough room
      if bit_offset + num_writes * bit_size > buffer.length * 8
        raise_buffer_error(:write, buffer, data_type, given_bit_offset, given_bit_size)
      end

      # Ensure the given_array_size is an even multiple of bit_size
      raise ArgumentError, "array_size #{given_array_size} not a multiple of bit_size #{given_bit_size}" if array_size % bit_size != 0

      raise ArgumentError, "too many values #{values.length} for given array_size #{given_array_size} and bit_size #{given_bit_size}" if num_writes < values.length

      # Check overflow type
      raise "unknown overflow type #{overflow}" unless OVERFLOW_TYPES.include?(overflow)

      case data_type
      when :STRING, :BLOCK
        #######################################
        # Handle :STRING and :BLOCK data types
        #######################################

        if byte_aligned
          num_writes.times do |index|
            self.write(values[index], bit_offset, bit_size, data_type, buffer, endianness, overflow)
            bit_offset += bit_size
          end
        else
          raise ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}"
        end

      when :INT, :UINT
        ###################################
        # Handle :INT and :UINT data types
        ###################################

        if byte_aligned and (bit_size == 8 or bit_size == 16 or bit_size == 32 or bit_size == 64)
          ###########################################################
          # Handle byte-aligned 8, 16, 32, and 64 bit :INT and :UINT
          ###########################################################

          case bit_size
          when 8
            if data_type == :INT
              values = self.check_overflow_array(values, -128, 127, 255, bit_size, data_type, overflow)
              packed = values.pack(PACK_8_BIT_INT_ARRAY)
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, 255, 255, bit_size, data_type, overflow)
              packed = values.pack(PACK_8_BIT_UINT_ARRAY)
            end

          when 16
            if data_type == :INT
              values = self.check_overflow_array(values, -32768, 32767, 65535, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_16_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_16_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 2)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, 65535, 65535, bit_size, data_type, overflow)
              if endianness == :BIG_ENDIAN
                packed = values.pack(PACK_BIG_ENDIAN_16_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                packed = values.pack(PACK_LITTLE_ENDIAN_16_BIT_UINT_ARRAY)
              end
            end

          when 32
            if data_type == :INT
              values = self.check_overflow_array(values, -2147483648, 2147483647, 4294967295, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_32_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_32_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 4)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, 4294967295, 4294967295, bit_size, data_type, overflow)
              if endianness == :BIG_ENDIAN
                packed = values.pack(PACK_BIG_ENDIAN_32_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                packed = values.pack(PACK_LITTLE_ENDIAN_32_BIT_UINT_ARRAY)
              end
            end

          when 64
            if data_type == :INT
              values = self.check_overflow_array(values, -9223372036854775808, 9223372036854775807, 18446744073709551615, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 8)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, 18446744073709551615, 18446744073709551615, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_UINT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_UINT_ARRAY)
                self.byte_swap_buffer!(packed, 8)
              end
            end
          end

          # Adjust packed size to hold number of items written
          buffer[lower_bound..upper_bound] = adjust_packed_size(num_bytes, packed) if num_bytes > 0

        else
          ##################################
          # Handle :INT and :UINT Bitfields
          ##################################

          raise ArgumentError, "write_array does not support little endian bit fields with bit_size greater than 1-bit" if endianness == :LITTLE_ENDIAN and bit_size > 1

          num_writes.times do |index|
            self.write(values[index], bit_offset, bit_size, data_type, buffer, endianness, overflow)
            bit_offset += bit_size
          end
        end

      when :FLOAT
        ##########################
        # Handle :FLOAT data type
        ##########################

        if byte_aligned
          case bit_size
          when 32
            if endianness == :BIG_ENDIAN
              packed = values.pack(PACK_BIG_ENDIAN_32_BIT_FLOAT_ARRAY)
            else # endianness == :LITTLE_ENDIAN
              packed = values.pack(PACK_LITTLE_ENDIAN_32_BIT_FLOAT_ARRAY)
            end

          when 64
            if endianness == :BIG_ENDIAN
              packed = values.pack(PACK_BIG_ENDIAN_64_BIT_FLOAT_ARRAY)
            else # endianness == :LITTLE_ENDIAN
              packed = values.pack(PACK_LITTLE_ENDIAN_64_BIT_FLOAT_ARRAY)
            end

          else
            raise ArgumentError, "bit_size is #{given_bit_size} but must be 32 or 64 for data_type #{data_type}"
          end

          # Adjust packed size to hold number of items written
          buffer[lower_bound..upper_bound] = adjust_packed_size(num_bytes, packed) if num_bytes > 0

        else
          raise ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}"
        end

      else
        ############################
        # Handle Unknown data types
        ############################
        raise ArgumentError, "data_type #{data_type} is not recognized"
      end # case data_type

      values
    end # def write_array

    # Adjusts the packed array to be the given number of bytes
    #
    # @param num_bytes [Integer] The desired number of bytes
    # @param packet [Array] The packed data buffer
    def self.adjust_packed_size(num_bytes, packed)
      difference = num_bytes - packed.length
      if difference > 0
        packed << (ZERO_STRING * difference)
      elsif difference < 0
        packed = packed[0..(packed.length - 1 + difference)]
      end
      packed
    end

    # Byte swaps every X bytes of data in a buffer overwriting the buffer
    #
    # @param buffer [String] Buffer to modify
    # @param num_bytes_per_word [Integer] Number of bytes per word that will be swapped
    # @return [String] buffer passed in as a parameter
    def self.byte_swap_buffer!(buffer, num_bytes_per_word)
      num_swaps = buffer.length / num_bytes_per_word
      index = 0
      num_swaps.times do
        range = index..(index + num_bytes_per_word - 1)
        buffer[range] = buffer[range].reverse
        index += num_bytes_per_word
      end
      buffer
    end

    # Byte swaps every X bytes of data in a buffer into a new buffer
    #
    # @param buffer [String] Buffer that will be copied then modified
    # @param num_bytes_per_word [Integer] Number of bytes per word that will be swapped
    # @return [String] modified buffer
    def self.byte_swap_buffer(buffer, num_bytes_per_word)
      buffer = buffer.clone
      self.byte_swap_buffer!(buffer, num_bytes_per_word)
    end

    # Checks for overflow of an integer data type
    #
    # @param value [Integer] Value to write into the buffer
    # @param min_value [Integer] Minimum allowed value
    # @param max_value [Integer] Maximum allowed value
    # @param hex_max_value [Integer] Maximum allowed value if specified in hex
    # @param bit_size [Integer] Size of the item in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param overflow [Symbol] {OVERFLOW_TYPES}
    # @return [Integer] Potentially modified value
    def self.check_overflow(value, min_value, max_value, hex_max_value, bit_size, data_type, overflow)
      if overflow != :TRUNCATE
        if value > max_value
          if overflow == :SATURATE
            value = max_value
          else
            if overflow == :ERROR or value > hex_max_value
              raise ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}"
            end
          end
        elsif value < min_value
          if overflow == :SATURATE
            value = min_value
          else
            raise ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}"
          end
        end
      end
      value
    end

    # Checks for overflow of an array of integer data types
    #
    # @param values [Array[Integer]] Values to write into the buffer
    # @param min_value [Integer] Minimum allowed value
    # @param max_value [Integer] Maximum allowed value
    # @param hex_max_value [Integer] Maximum allowed value if specified in hex
    # @param bit_size [Integer] Size of the item in bits
    # @param data_type [Symbol] {DATA_TYPES}
    # @param overflow [Symbol] {OVERFLOW_TYPES}
    # @return [Array[Integer]] Potentially modified values
    def self.check_overflow_array(values, min_value, max_value, hex_max_value, bit_size, data_type, overflow)
      if overflow != :TRUNCATE
        values.each_with_index do |value, index|
          values[index] = check_overflow(value, min_value, max_value, hex_max_value, bit_size, data_type, overflow)
        end
      end
      values
    end

  end # class BinaryAccessor

end # module Cosmos
