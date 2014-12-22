# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/binary_accessor'
require 'cosmos/streams/stream_protocol'
require 'cosmos/config/config_parser'

module Cosmos

  # This StreamProtocol delineates packets using a length field at a fixed
  # location in each packet.
  class LengthStreamProtocol < StreamProtocol

    # @param length_bit_offset [Integer] The bit offset of the length field
    # @param length_bit_size [Integer] The size in bits of the length field
    # @param length_value_offset [Integer] The offset to apply to the length
    #   value once it has been read from the packet. The value in the length
    #   field itself plus the length value offset MUST equal the total bytes in
    #   the stream including any discarded bytes.
    #   For example: if your length field really means "length - 1" this value should be 1.
    # @param length_bytes_per_count [Integer] The number of bytes per each
    #   length field 'count'. This is used if the units of the length field is
    #   something other than bytes, for example words.
    # @param length_endianness [String] The endianness of the length field.
    #   Must be either BIG_ENDIAN or LITTLE_ENDIAN.
    # @param discard_leading_bytes (see StreamProtocol#initialize)
    # @param sync_pattern (see StreamProtocol#initialize)
    # @param max_length [Integer] The maximum allowed value of the length field
    # @param fill_length_and_sync_pattern [Boolean] Fill the length field and sync
    #    pattern when writing packets
    def initialize(
      length_bit_offset = 0,
      length_bit_size = 16,
      length_value_offset = 0,
      length_bytes_per_count = 1,
      length_endianness = 'BIG_ENDIAN',
      discard_leading_bytes = 0,
      sync_pattern = nil,
      max_length = nil,
      fill_length_and_sync_pattern = false
    )
      super(discard_leading_bytes, sync_pattern, fill_length_and_sync_pattern)

      # Save length field attributes
      @length_bit_offset = Integer(length_bit_offset)
      @length_bit_size = Integer(length_bit_size)
      @length_value_offset = Integer(length_value_offset)
      @length_bytes_per_count = Integer(length_bytes_per_count)

      # Save endianness
      if length_endianness.to_s.upcase == 'LITTLE_ENDIAN'
        @length_endianness = :LITTLE_ENDIAN
      else
        @length_endianness = :BIG_ENDIAN
      end

      # Derive number of bytes required to contain entire length field
      if @length_endianness == :BIG_ENDIAN or ((@length_bit_offset % 8) == 0)
        length_bits_needed = @length_bit_offset + @length_bit_size
        length_bits_needed += 8 if (length_bits_needed % 8) != 0
        @length_bytes_needed = ((length_bits_needed - 1)/ 8) + 1
      else
        @length_bytes_needed = (length_bit_offset / 8) + 1
      end

      # Save max length setting
      @max_length = ConfigParser.handle_nil(max_length)
      @max_length = Integer(@max_length) if @max_length
    end

    # See StreamProtocol#pre_write_packet
    def pre_write_packet(packet)
      data = super(packet)
      if @fill_sync_pattern # and length
        # Fill the length field
        length = (data.length - @length_value_offset) / @length_bytes_per_count
        BinaryAccessor.write(length,
          @length_bit_offset,
          @length_bit_size,
          :UINT,
          data,
          @length_endianness,
          :ERROR)

        # Also write the new length field into the packet that will be logged if it exists in the packet
        if @discard_leading_bytes > 0
          # The write above did not write into the original packet
          original_length_bit_offset = @length_bit_offset - (@discard_leading_bytes * 8)
          if original_length_bit_offset >= 0
            original_data = packet.buffer(false)
            BinaryAccessor.write(length,
              original_length_bit_offset,
              @length_bit_size,
              :UINT,
              original_data,
              @length_endianness,
              :ERROR)
          end
        end
      end
      data
    end

    protected

    def reduce_to_single_packet
      # Make sure we have at least enough data to reach the length field
      read_minimum_size(@length_bytes_needed)
      return nil if @data.length <= 0

      # Determine the packet's length
      length = BinaryAccessor.read(@length_bit_offset,
                                   @length_bit_size,
                                   :UINT,
                                   @data,
                                   @length_endianness)
      raise "Length value received larger than max_length: #{length} > #{@max_length}" if @max_length and length > @max_length
      packet_length = (length * @length_bytes_per_count) + @length_value_offset

      # Make sure we have enough data for the packet
      read_minimum_size(packet_length)
      return nil if @data.length <= 0

      # Reduce to packet data and setup current_data for next packet
      packet_data = @data[0..(packet_length - 1)]
      @data.replace(@data[packet_length..-1])

      packet_data
    end

  end # class LengthStreamProtocol

end # module Cosmos
