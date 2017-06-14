# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/binary_accessor'
require 'cosmos/interfaces/protocols/stream_protocol'
require 'cosmos/config/config_parser'

module Cosmos
  # Protocol which delineates packets using a length field at a fixed
  # location in each packet.
  module LengthStreamProtocol
    include StreamProtocol

    # Set procotol specific options
    # @param procotol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      super(protocol, params)
      configure_stream_protocol(*params) if protocol == 'LengthStreamProtocol'
    end

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
    def configure_stream_protocol(
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

    # Called to perform modifications on a command packet before it is send
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def pre_write_packet(packet)
      packet = super(packet) # Allow stream_protocol to set the sync if needed
      if @fill_fields
        # If the start of the length field is past what we discard, then the
        # length field is inside the packet
        if @length_bit_offset >= (@discard_leading_bytes * 8)
          length = calculate_length(packet.buffer.length)
          # Subtract off the discarded bytes since they haven't been added yet
          # Adding bytes to the stream happens in the pre_write_data method
          offset = @length_bit_offset - (@discard_leading_bytes * 8)
          # Directly write the packet buffer and fill in the length
          BinaryAccessor.write(length, offset, @length_bit_size, :UINT,
                               packet.buffer(false), @length_endianness, :ERROR)
        end
      end
      packet
    end

    # Called to perform modifications on write data before making it into a packet
    #
    # @param packet_data [String] Raw packet data
    # @return [String] Potentially modified packet data
    def pre_write_data(packet_data)
      if @fill_fields
        # If the start of the length field is before what we discard, then the
        # length field is outside the packet
        if @length_bit_offset < (@discard_leading_bytes * 8)
          length = calculate_length(packet_data.length)
          sync_length = @sync_pattern ? @sync_pattern.length : 0
          # Prepend data except for the sync which will be done by super()
          packet_data = ("\x00" * (@discard_leading_bytes - sync_length)) << packet_data
          # Adjust the discard so super() adds the correct amount
          @discard_leading_bytes -= (@discard_leading_bytes - sync_length)
          offset = @length_bit_offset - (sync_length * 8)
          # Directly write the packet buffer and fill in the length
          BinaryAccessor.write(length, offset, @length_bit_size, :UINT,
                               packet_data, @length_endianness, :ERROR)
        end
        packet_data = super(packet_data) # Allow stream_protocol to set the sync if needed
      end
      packet_data
    end

    protected

    def calculate_length(buffer_length)
      length = (buffer_length + @discard_leading_bytes) /
        @length_bytes_per_count - @length_value_offset
      if @max_length && length > @max_length
        raise "Calculated buffer length #{buffer_length} larger than max_length #{@max_length}"
      end
      length
    end

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
  end
end
