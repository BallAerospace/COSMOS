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

    def initialize(write_item_name, strip_crc, bad_strategy, bit_offset,
                   bit_size = 32, poly = nil, seed = nil, xor = nil, reflect = nil)
      @write_item_name = ConfigParser.handle_nil(write_item_name)
      @strip_crc = ConfigParser.handle_true_false(strip_crc)
      raise "Invalid strip CRC of '#{strip_crc}'. Must be TRUE or FALSE." unless !!@strip_crc == @strip_crc
      case bad_strategy
      when ERROR, DISCONNECT
        @bad_strategy = bad_strategy
      else
        raise "Invalid bad CRC strategy of #{bad_strategy}. Must be ERROR or DISCONNECT."
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
        @pack = 'n'
        if args.empty?
          @crc = Crc16.new
        else
          @crc = Crc16.new(*args)
        end
      when 32
        @pack = 'N'
        if args.empty?
          @crc = Crc32.new
        else
          @crc = Crc32.new(*args)
        end
      when 64
        @pack = 'NN'
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
      end_range = (@bit_offset + @bit_size) / 8
      end_range = -1 if end_range == 0
      if @bit_size == 64
        crc = data[(@bit_offset/8)..end_range].unpack(@pack)
        crc = (crc[0] << 32) | crc[1]
      else
        crc = data[(@bit_offset/8)..end_range].unpack(@pack)[0]
      end
      calculated_crc = @crc.calc(data[0...(@bit_offset/8)])
      if calculated_crc != crc
        Logger.error "Invalid CRC detected! Calculated 0x#{calculated_crc.to_s(16).upcase} vs found 0x#{crc.to_s(16).upcase}."
        if @bad_strategy == DISCONNECT
          return :DISCONNECT
        end
      end
      if @strip_crc
        new_data = data.dup
        new_data = new_data[0...(@bit_offset/8)]
        new_data << data[end_range..-1] unless end_range == -1
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
          data << [crc >> 32].pack("N")
          data << [crc & 0xFFFFFFFF].pack("N")
        else
          data << [@crc.calc(data)].pack(@pack)
        end
      end
      data
    end
  end
end
