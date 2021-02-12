# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# This file contains the implementation of the BinaryAccessor class.
# This class allows for easy reading and writing of binary data in Ruby

require 'cosmos/ext/packet' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']

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

    if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_ENV']
      MIN_INT8 = -128
      MAX_INT8 = 127
      MAX_UINT8 = 255
      MIN_INT16 = -32768
      MAX_INT16 = 32767
      MAX_UINT16 = 65535
      MIN_INT32  = -(2 ** 31)
      MAX_INT32  = (2 ** 31) - 1
      MAX_UINT32 = (2 ** 32) - 1
      MIN_INT64  = -(2 ** 63)
      MAX_INT64  = (2 ** 63) - 1
      MAX_UINT64 = (2 ** 64) - 1
    end

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

    if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
      # Reads binary data of any data type from a buffer
      #
      # @param bit_offset [Integer] Bit offset to the start of the item. A
      #   negative number means to offset from the end of the buffer.
      # @param bit_size [Integer] Size of the item in bits
      # @param data_type [Symbol] {DATA_TYPES}
      # @param buffer [String] Binary string buffer to read from
      # @param endianness [Symbol] {ENDIANNESS}
      # @return [Integer] value read from the buffer
      def self.read(bit_offset, bit_size, data_type, buffer, endianness)
        given_bit_offset = bit_offset
        given_bit_size = bit_size

        bit_offset = check_bit_offset_and_size(:read, given_bit_offset, given_bit_size, data_type, buffer)

        # If passed a negative bit size with strings or blocks
        # recalculate based on the buffer length
        if (bit_size <= 0) && ((data_type == :STRING) || (data_type == :BLOCK))
          bit_size = (buffer.length * 8) - bit_offset + bit_size
          if bit_size == 0
            return ""
          elsif bit_size < 0
            raise_buffer_error(:read, buffer, data_type, given_bit_offset, given_bit_size)
          end
        end

        result, lower_bound, upper_bound = check_bounds_and_buffer_size(bit_offset, bit_size, buffer.length, endianness, data_type)
        raise_buffer_error(:read, buffer, data_type, given_bit_offset, given_bit_size) unless result

        if (data_type == :STRING) || (data_type == :BLOCK)
          #######################################
          # Handle :STRING and :BLOCK data types
          #######################################

          if byte_aligned(bit_offset)
            if data_type == :STRING
              return buffer[lower_bound..upper_bound].unpack('Z*')[0]
            else
              return buffer[lower_bound..upper_bound].unpack('a*')[0]
            end
          else
            raise(ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}")
          end

        elsif (data_type == :INT) || (data_type == :UINT)
          ###################################
          # Handle :INT and :UINT data types
          ###################################

          if byte_aligned(bit_offset) && even_bit_size(bit_size)

            if data_type == :INT
              ###########################################################
              # Handle byte-aligned 8, 16, 32, and 64 bit :INT
              ###########################################################

              case bit_size
              when 8
                return buffer[lower_bound].unpack(PACK_8_BIT_INT)[0]
              when 16
                if endianness == HOST_ENDIANNESS
                  return buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_16_BIT_INT)[0]
                else # endianness != HOST_ENDIANNESS
                  temp = buffer[lower_bound..upper_bound].reverse
                  return temp.unpack(PACK_NATIVE_16_BIT_INT)[0]
                end
              when 32
                if endianness == HOST_ENDIANNESS
                  return buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_32_BIT_INT)[0]
                else # endianness != HOST_ENDIANNESS
                  temp = buffer[lower_bound..upper_bound].reverse
                  return temp.unpack(PACK_NATIVE_32_BIT_INT)[0]
                end
              when 64
                if endianness == HOST_ENDIANNESS
                  return buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_64_BIT_INT)[0]
                else # endianness != HOST_ENDIANNESS
                  temp = buffer[lower_bound..upper_bound].reverse
                  return temp.unpack(PACK_NATIVE_64_BIT_INT)[0]
                end
              end
            else # data_type == :UINT
              ###########################################################
              # Handle byte-aligned 8, 16, 32, and 64 bit :UINT
              ###########################################################

              case bit_size
              when 8
                return buffer.getbyte(lower_bound)
              when 16
                if endianness == :BIG_ENDIAN
                  return buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_16_BIT_UINT)[0]
                else # endianness == :LITTLE_ENDIAN
                  return buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_16_BIT_UINT)[0]
                end
              when 32
                if endianness == :BIG_ENDIAN
                  return buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_32_BIT_UINT)[0]
                else # endianness == :LITTLE_ENDIAN
                  return buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_32_BIT_UINT)[0]
                end
              when 64
                if endianness == HOST_ENDIANNESS
                  return buffer[lower_bound..upper_bound].unpack(PACK_NATIVE_64_BIT_UINT)[0]
                else # endianness != HOST_ENDIANNESS
                  temp = buffer[lower_bound..upper_bound].reverse
                  return temp.unpack(PACK_NATIVE_64_BIT_UINT)[0]
                end
              end
            end

          else
            ##########################
            # Handle :INT and :UINT Bitfields
            ##########################

            #Extract Data for Bitfield
            if endianness == :LITTLE_ENDIAN
              #Bitoffset always refers to the most significant bit of a bitfield
              num_bytes = (((bit_offset % 8) + bit_size - 1) / 8) + 1
              upper_bound = bit_offset / 8
              lower_bound = upper_bound - num_bytes + 1

              if lower_bound < 0
                raise(ArgumentError, "LITTLE_ENDIAN bitfield with bit_offset #{given_bit_offset} and bit_size #{given_bit_size} is invalid")
              end

              temp_data = buffer[lower_bound..upper_bound].reverse
            else
              temp_data = buffer[lower_bound..upper_bound]
            end

            #Determine temp upper bound
            temp_upper = upper_bound - lower_bound

            # Handle Bitfield
            start_bits = bit_offset % 8
            start_mask = ~(0xFF << (8 - start_bits))
            total_bits = (temp_upper + 1) * 8
            right_shift = total_bits - start_bits - bit_size

            #Mask off unwanted bits at beginning
            temp = temp_data.getbyte(0) & start_mask

            if upper_bound > lower_bound
              #Combine bytes into a FixNum
              temp_data[1..temp_upper].each_byte {|temp_value| temp = temp << 8; temp = temp + temp_value }
            end

            # Shift off unwanted bits at end
            temp = temp >> right_shift

            if data_type == :INT
              #Convert to negative if necessary
              if ((bit_size > 1) && (temp[bit_size - 1] == 1))
                temp = -((1 << bit_size) - temp)
              end
            end

            return temp
          end

        elsif data_type == :FLOAT
          ##########################
          # Handle :FLOAT data type
          ##########################

          if byte_aligned(bit_offset)
            case bit_size
            when 32
              if endianness == :BIG_ENDIAN
                return buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_32_BIT_FLOAT)[0]
              else # endianness == :LITTLE_ENDIAN
                return buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_32_BIT_FLOAT)[0]
              end
            when 64
              if endianness == :BIG_ENDIAN
                return buffer[lower_bound..upper_bound].unpack(PACK_BIG_ENDIAN_64_BIT_FLOAT)[0]
              else # endianness == :LITTLE_ENDIAN
                return buffer[lower_bound..upper_bound].unpack(PACK_LITTLE_ENDIAN_64_BIT_FLOAT)[0]
              end
            else
              raise(ArgumentError, "bit_size is #{given_bit_size} but must be 32 or 64 for data_type #{data_type}")
            end
          else
            raise(ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}")
          end

        else
          ############################
          # Handle Unknown data types
          ############################

          raise(ArgumentError, "data_type #{data_type} is not recognized")
        end

        return return_value
      end

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
      def self.write(value, bit_offset, bit_size, data_type, buffer, endianness, overflow)
        given_bit_offset = bit_offset
        given_bit_size = bit_size

        bit_offset = check_bit_offset_and_size(:write, given_bit_offset, given_bit_size, data_type, buffer)

        # If passed a negative bit size with strings or blocks
        # recalculate based on the value length in bytes
        if (bit_size <= 0) && ((data_type == :STRING) || (data_type == :BLOCK))
          value = value.to_s
          bit_size = value.length * 8
        end

        result, lower_bound, upper_bound = check_bounds_and_buffer_size(bit_offset, bit_size, buffer.length, endianness, data_type)
        raise_buffer_error(:write, buffer, data_type, given_bit_offset, given_bit_size) if !result && (given_bit_size > 0)

        # Check overflow type
        if (overflow != :TRUNCATE) && (overflow != :SATURATE) && (overflow != :ERROR) && (overflow != :ERROR_ALLOW_HEX)
          raise(ArgumentError, "unknown overflow type #{overflow}")
        end

        if (data_type == :STRING) || (data_type == :BLOCK)
          #######################################
          # Handle :STRING and :BLOCK data types
          #######################################
          value = value.to_s

          if byte_aligned(bit_offset)
            temp = value
            if given_bit_size <= 0
              end_bytes = -(given_bit_size / 8)
              old_upper_bound = buffer.length - 1 - end_bytes
              # Lower bound + end_bytes can never be more than 1 byte outside of the given buffer
              if (lower_bound + end_bytes) > buffer.length
                raise_buffer_error(:write, buffer, data_type, given_bit_offset, given_bit_size)
              end

              if old_upper_bound < lower_bound
                # String was completely empty
                if end_bytes > 0
                  # Preserve bytes at end of buffer
                  buffer << "\000" * value.length
                  buffer[lower_bound + value.length, end_bytes] = buffer[lower_bound, end_bytes]
                end
              elsif bit_size == 0
                # Remove entire string
                buffer[lower_bound, old_upper_bound - lower_bound + 1] = ''
              elsif upper_bound < old_upper_bound
                # Remove extra bytes from old string
                buffer[upper_bound + 1, old_upper_bound - upper_bound] = ''
              elsif (upper_bound > old_upper_bound) && (end_bytes > 0)
                # Preserve bytes at end of buffer
                diff = upper_bound - old_upper_bound
                buffer << "\000" * diff
                buffer[upper_bound + 1, end_bytes] = buffer[old_upper_bound + 1, end_bytes]
              end
            else # given_bit_size > 0
              byte_size = bit_size / 8
              if value.length < byte_size
                # Pad the requested size with zeros
                temp = value.ljust(byte_size, "\000")
              elsif value.length > byte_size
                if overflow == :TRUNCATE
                  # Resize the value to fit the field
                  value[byte_size, value.length - byte_size] = ''
                else
                  raise(ArgumentError, "value of #{value.length} bytes does not fit into #{byte_size} bytes for data_type #{data_type}")
                end
              end
            end
            if bit_size != 0
              buffer[lower_bound, temp.length] = temp
            end
          else
            raise(ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}")
          end

        elsif (data_type == :INT) || (data_type == :UINT)
          ###################################
          # Handle :INT data type
          ###################################
          value = Integer(value)
          min_value, max_value, hex_max_value = get_check_overflow_ranges(bit_size, data_type)
          value = check_overflow(value, min_value, max_value, hex_max_value, bit_size, data_type, overflow)

          if byte_aligned(bit_offset) && even_bit_size(bit_size)
            ###########################################################
            # Handle byte-aligned 8, 16, 32, and 64 bit
            ###########################################################

            if data_type == :INT
              ###########################################################
              # Handle byte-aligned 8, 16, 32, and 64 bit :INT
              ###########################################################

              case bit_size
              when 8
                buffer.setbyte(lower_bound, value)
              when 16
                if endianness == HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_16_BIT_INT)
                else # endianness != HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_16_BIT_INT).reverse
                end
              when 32
                if endianness == HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_32_BIT_INT)
                else # endianness != HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_32_BIT_INT).reverse
                end
              when 64
                if endianness == HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_64_BIT_INT)
                else # endianness != HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_64_BIT_INT).reverse
                end
              end
            else # data_type == :UINT
              ###########################################################
              # Handle byte-aligned 8, 16, 32, and 64 bit :UINT
              ###########################################################

              case bit_size
              when 8
                buffer.setbyte(lower_bound, value)
              when 16
                if endianness == :BIG_ENDIAN
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_BIG_ENDIAN_16_BIT_UINT)
                else # endianness == :LITTLE_ENDIAN
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_LITTLE_ENDIAN_16_BIT_UINT)
                end
              when 32
                if endianness == :BIG_ENDIAN
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_BIG_ENDIAN_32_BIT_UINT)
                else # endianness == :LITTLE_ENDIAN
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_LITTLE_ENDIAN_32_BIT_UINT)
                end
              when 64
                if endianness == HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_64_BIT_UINT)
                else # endianness != HOST_ENDIANNESS
                  buffer[lower_bound..upper_bound] = [value].pack(PACK_NATIVE_64_BIT_UINT).reverse
                end
              end
            end

          else
            ###########################################################
            # Handle bit fields
            ###########################################################

            # Extract Existing Data
            if endianness == :LITTLE_ENDIAN
              # Bitoffset always refers to the most significant bit of a bitfield
              num_bytes = (((bit_offset % 8) + bit_size - 1) / 8) + 1
              upper_bound = bit_offset / 8
              lower_bound = upper_bound - num_bytes + 1
              if lower_bound < 0
                raise(ArgumentError, "LITTLE_ENDIAN bitfield with bit_offset #{given_bit_offset} and bit_size #{given_bit_size} is invalid")
              end
              temp_data = buffer[lower_bound..upper_bound].reverse
            else
              temp_data = buffer[lower_bound..upper_bound]
            end

            # Determine temp upper bound
            temp_upper = upper_bound - lower_bound

            # Determine Values needed to Handle Bitfield
            start_bits = bit_offset % 8
            start_mask = (0xFF << (8 - start_bits))
            total_bits = (temp_upper + 1) * 8
            end_bits = total_bits - start_bits - bit_size
            end_mask = ~(0xFF << end_bits)

            # Add in Start Bits
            temp = temp_data.getbyte(0) & start_mask

            # Adjust value to correct number of bits
            temp_mask = (2 ** bit_size) - 1
            temp_value = value & temp_mask

            # Add in New Data
            temp = (temp << (bit_size - (8 - start_bits))) + temp_value

            # Add in Remainder of Existing Data
            temp = (temp << end_bits) + (temp_data.getbyte(temp_upper) & end_mask)

            # Extract into an array of bytes
            temp_array = []
            (0..temp_upper).each { temp_array.insert(0, (temp & 0xFF)); temp = temp >> 8 }

            # Store into data
            if endianness == :LITTLE_ENDIAN
              buffer[lower_bound..upper_bound] = temp_array.pack(PACK_8_BIT_UINT_ARRAY).reverse
            else
              buffer[lower_bound..upper_bound] = temp_array.pack(PACK_8_BIT_UINT_ARRAY)
            end

          end

        elsif data_type == :FLOAT
          ##########################
          # Handle :FLOAT data type
          ##########################
          value = Float(value)

          if byte_aligned(bit_offset)
            case bit_size
            when 32
              if endianness == :BIG_ENDIAN
                buffer[lower_bound..upper_bound] = [value].pack(PACK_BIG_ENDIAN_32_BIT_FLOAT)
              else # endianness == :LITTLE_ENDIAN
                buffer[lower_bound..upper_bound] = [value].pack(PACK_LITTLE_ENDIAN_32_BIT_FLOAT)
              end
            when 64
              if endianness == :BIG_ENDIAN
                buffer[lower_bound..upper_bound] = [value].pack(PACK_BIG_ENDIAN_64_BIT_FLOAT)
              else # endianness == :LITTLE_ENDIAN
                buffer[lower_bound..upper_bound] = [value].pack(PACK_LITTLE_ENDIAN_64_BIT_FLOAT)
              end
            else
              raise(ArgumentError, "bit_size is #{given_bit_size} but must be 32 or 64 for data_type #{data_type}")
            end
          else
            raise(ArgumentError, "bit_offset #{given_bit_offset} is not byte aligned for data_type #{data_type}")
          end

        else
          ############################
          # Handle Unknown data types
          ############################

          raise(ArgumentError, "data_type #{data_type} is not recognized")
        end

        return value
      end

      protected

      # Check the bit size and bit offset for problems. Recalulate the bit offset
      # and return back through the passed in pointer.
      def self.check_bit_offset_and_size(read_or_write, given_bit_offset, given_bit_size, data_type, buffer)
        bit_offset = given_bit_offset

        if (given_bit_size <= 0) && (data_type != :STRING) && (data_type != :BLOCK)
          raise(ArgumentError, "bit_size #{given_bit_size} must be positive for data types other than :STRING and :BLOCK")
        end

        if (given_bit_size <= 0) && (given_bit_offset < 0)
          raise(ArgumentError, "negative or zero bit_sizes (#{given_bit_size}) cannot be given with negative bit_offsets (#{given_bit_offset})")
        end

        if given_bit_offset < 0
          bit_offset = (buffer.length * 8) + bit_offset
          if bit_offset < 0
            raise_buffer_error(read_or_write, buffer, data_type, given_bit_offset, given_bit_size)
          end
        end

        return bit_offset
      end

      # Calculate the bounds of the string to access the item based on the bit_offset and bit_size.
      # Also determine if the buffer size is sufficient.
      def self.check_bounds_and_buffer_size(bit_offset, bit_size, buffer_length, endianness, data_type)
        result = true # Assume ok

        # Define bounds of string to access this item
        lower_bound = bit_offset / 8
        upper_bound = (bit_offset + bit_size - 1) / 8

        # Sanity check buffer size
        if upper_bound >= buffer_length
          # If it's not the special case of little endian bit field then we fail and return false
          if !( (endianness == :LITTLE_ENDIAN) &&
                 ((data_type == :INT) || (data_type == :UINT)) &&
                 # Not byte aligned with an even bit size
                 (!( (byte_aligned(bit_offset)) && (even_bit_size(bit_size)) )) &&
                 (lower_bound < buffer_length)
             )
            result = false
          end
        end
        return result, lower_bound, upper_bound
      end

      def self.get_check_overflow_ranges(bit_size, data_type)
        min_value = 0 # Default for UINT cases

        case bit_size
        when 8
          hex_max_value = MAX_UINT8
          if data_type == :INT
            min_value = MIN_INT8
            max_value = MAX_INT8
          else
            max_value = MAX_UINT8
          end
        when 16
          hex_max_value = MAX_UINT16
          if data_type == :INT
            min_value = MIN_INT16
            max_value = MAX_INT16
          else
            max_value = MAX_UINT16
          end
        when 32
          hex_max_value = MAX_UINT32
          if data_type == :INT
            min_value = MIN_INT32
            max_value = MAX_INT32
          else
            max_value = MAX_UINT32
          end
        when 64
          hex_max_value = MAX_UINT64
          if data_type == :INT
            min_value = MIN_INT64
            max_value = MAX_INT64
          else
            max_value = MAX_UINT64
          end
        else # Bitfield
          if data_type == :INT
            # Note signed integers must allow up to the maximum unsigned value to support values given in hex
            if bit_size > 1
              max_value = 2 ** (bit_size - 1)
              # min_value = -(2 ** bit_size - 1)
              min_value = -max_value
              # max_value = (2 ** bit_size - 1) - 1
              max_value -= 1
              # hex_max_value = (2 ** bit_size) - 1
              hex_max_value = (2 ** bit_size) - 1
            else # 1-bit signed
              min_value = -1
              max_value = 1
              hex_max_value = 1
            end
          else
            max_value = (2 ** bit_size) - 1
            hex_max_value = max_value
          end
        end

        return min_value, max_value, hex_max_value
      end

      def self.byte_aligned(value)
        (value % 8) == 0
      end

      def self.even_bit_size(bit_size)
        (bit_size == 8) || (bit_size == 16) || (bit_size == 32) || (bit_size == 64)
      end

      public
    end

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
              values = self.check_overflow_array(values, MIN_INT8, MAX_INT8, MAX_UINT8, bit_size, data_type, overflow)
              packed = values.pack(PACK_8_BIT_INT_ARRAY)
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, MAX_UINT8, MAX_UINT8, bit_size, data_type, overflow)
              packed = values.pack(PACK_8_BIT_UINT_ARRAY)
            end

          when 16
            if data_type == :INT
              values = self.check_overflow_array(values, MIN_INT16, MAX_INT16, MAX_UINT16, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_16_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_16_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 2)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, MAX_UINT16, MAX_UINT16, bit_size, data_type, overflow)
              if endianness == :BIG_ENDIAN
                packed = values.pack(PACK_BIG_ENDIAN_16_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                packed = values.pack(PACK_LITTLE_ENDIAN_16_BIT_UINT_ARRAY)
              end
            end

          when 32
            if data_type == :INT
              values = self.check_overflow_array(values, MIN_INT32, MAX_INT32, MAX_UINT32, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_32_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_32_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 4)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, MAX_UINT32, MAX_UINT32, bit_size, data_type, overflow)
              if endianness == :BIG_ENDIAN
                packed = values.pack(PACK_BIG_ENDIAN_32_BIT_UINT_ARRAY)
              else # endianness == :LITTLE_ENDIAN
                packed = values.pack(PACK_LITTLE_ENDIAN_32_BIT_UINT_ARRAY)
              end
            end

          when 64
            if data_type == :INT
              values = self.check_overflow_array(values, MIN_INT64, MAX_INT64, MAX_UINT64, bit_size, data_type, overflow)
              if endianness == HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_INT_ARRAY)
              else # endianness != HOST_ENDIANNESS
                packed = values.pack(PACK_NATIVE_64_BIT_INT_ARRAY)
                self.byte_swap_buffer!(packed, 8)
              end
            else # data_type == :UINT
              values = self.check_overflow_array(values, 0, MAX_UINT64, MAX_UINT64, bit_size, data_type, overflow)
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
    # @param packed [Array] The packed data buffer
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
      if overflow == :TRUNCATE
        # Note this will always convert to unsigned equivalent for signed integers
        value = value % (hex_max_value + 1)
      else
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
