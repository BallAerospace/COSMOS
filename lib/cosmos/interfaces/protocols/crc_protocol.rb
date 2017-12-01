# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/protocol'
require 'cosmos/utilities/crc'
require 'thread'

module Cosmos
  # Creates a CRC on write and verifies a CRC on read
  class CrcProtocol < Protocol
    ERROR = "ERROR" # on CRC mismatch
    DISCONNECT = "DISCONNECT" # on CRC mismatch

    # @param write_item_name [String/nil] Item to fill with calculated CRC value for outgoing packets (nil = don't fill)
    # @param strip_crc [Boolean] Whether or not to remove the CRC from incoming packets
    # @param bad_strategy [ERROR/DISCONNECT] How to handle CRC errors on incoming packets.  ERROR = Just log the error, DISCONNECT = Disconnect interface
    # @param bit_offset [Integer] Bit offset of the CRC in the data.  Can be negative to indicate distance from end of packet
    # @param bit_size [Integer] Bit size of the CRC - Must be 16, 32, or 64
    # @param endianness [BIG_ENDIAN/LITTLE_ENDIAN] Endianness of the CRC
    # @param poly [Integer] Polynomial to use when calculating the CRC
    # @param seed [Integer] Seed value to start the calculation
    # @param xor [Boolean] Whether to XOR the CRC result with 0xFFFF
    # @param reflect [Boolean] Whether to bit reverse each byte of data before calculating the CRC
    # @param allow_empty_data [true/false/nil] See Protocol#initialize
    def initialize(
      write_item_name = nil,
      strip_crc = false,
      bad_strategy = "ERROR",
      bit_offset = -32,
      bit_size = 32,
      endianness = 'BIG_ENDIAN',
      poly = nil,
      seed = nil,
      xor = nil,
      reflect = nil,
      allow_empty_data = nil
    )
      super(allow_empty_data)
      @write_item_name = ConfigParser.handle_nil(write_item_name)
      @strip_crc = ConfigParser.handle_true_false(strip_crc)
      raise "Invalid strip CRC of '#{strip_crc}'. Must be TRUE or FALSE." unless !!@strip_crc == @strip_crc

      case bad_strategy
      when ERROR, DISCONNECT
        @bad_strategy = bad_strategy
      else
        raise "Invalid bad CRC strategy of #{bad_strategy}. Must be ERROR or DISCONNECT."
      end

      case endianness.to_s.upcase
      when 'BIG_ENDIAN'
        @endianness = :BIG_ENDIAN # Convert to symbol for use in BinaryAccessor.write
      when 'LITTLE_ENDIAN'
        @endianness = :LITTLE_ENDIAN # Convert to symbol for use in BinaryAccessor.write
      else
        raise "Invalid endianness '#{endianness}'. Must be BIG_ENDIAN or LITTLE_ENDIAN."
      end

      @bit_offset = Integer(bit_offset)
      raise "Invalid bit offset of #{bit_offset}. Must be divisible by 8." if bit_offset % 8 != 0
      @bit_size = Integer(bit_size)
      poly = Integer(poly) if poly
      seed = Integer(seed) if seed
      xor = ConfigParser.handle_true_false(xor) if xor
      raise "Invalid XOR value of '#{xor}'. Must be TRUE or FALSE." if xor && !!xor != xor
      reflect = ConfigParser.handle_true_false(reflect) if reflect
      raise "Invalid reflect value of '#{reflect}'. Must be TRUE or FALSE." if reflect && !!reflect != reflect
      # Built the CRC arguments array. All subsequent arguments are dependent
      # on the previous ones so we build it up incrementally.
      args = []
      if poly
        args << poly
        if seed
          args << seed
          unless xor.nil? # Can't check raw variable because it could be false
            args << xor
            unless reflect.nil? # Can't check raw variable because it could be false
              args << reflect
            end
          end
        end
      end

      case bit_size
      when 16
        @pack = (@endianness == :BIG_ENDIAN) ? 'n' : 'v'
        if args.empty?
          @crc = Crc16.new
        else
          @crc = Crc16.new(*args)
        end
      when 32
        @pack = (@endianness == :BIG_ENDIAN) ? 'N' : 'V'
        if args.empty?
          @crc = Crc32.new
        else
          @crc = Crc32.new(*args)
        end
      when 64
        @pack = (@endianness == :BIG_ENDIAN) ? 'N' : 'V'
        if args.empty?
          @crc = Crc64.new
        else
          @crc = Crc64.new(*args)
        end
      else
        raise "Invalid bit size of #{bit_size}. Must be 16, 32, or 64."
      end
    end

    def read_data(data)
      return super(data) if (data.length <= 0)

      crc = BinaryAccessor.read(@bit_offset, @bit_size, :UINT, data, @endianness)
      calculated_crc = @crc.calc(data[0...(@bit_offset / 8)])
      if calculated_crc != crc
        Logger.error "Invalid CRC detected! Calculated 0x#{calculated_crc.to_s(16).upcase} vs found 0x#{crc.to_s(16).upcase}."
        if @bad_strategy == DISCONNECT
          return :DISCONNECT
        end
      end
      if @strip_crc
        new_data = data.dup
        new_data = new_data[0...(@bit_offset / 8)]
        end_range = (@bit_offset + @bit_size) / 8
        new_data << data[end_range..-1] if end_range != 0
        return new_data
      end
      return data
    end

    def write_packet(packet)
      if @write_item_name
        end_range = packet.get_item(@write_item_name).bit_offset / 8
        crc = @crc.calc(packet.buffer(false)[0...end_range])
        packet.write(@write_item_name, crc)
      end
      packet
    end

    def write_data(data)
      unless @write_item_name
        if @bit_size == 64
          crc = @crc.calc(data)
          data << ("\x00" * 8)
          BinaryAccessor.write((crc >> 32), -64, 32, :UINT, data, @endianness, :ERROR)
          BinaryAccessor.write((crc & 0xFFFFFFFF), -32, 32, :UINT, data, @endianness, :ERROR)
        else
          crc = @crc.calc(data)
          data << ("\x00" * (@bit_size / 8))
          BinaryAccessor.write(crc, -@bit_size, @bit_size, :UINT, data, @endianness, :ERROR)
        end
      end
      data
    end
  end
end
