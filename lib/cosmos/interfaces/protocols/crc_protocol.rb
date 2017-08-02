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
    STRIP_ON_READ = "STRIP_ON_READ"
    ERROR = "ERROR" # on CRC mismatch
    DISCONNECT = "DISCONNECT" # on CRC mismatch

    def initialize(item_name, append_remove, bad_strategy, bit_offset,
                   bit_size = 32, poly = nil, seed = nil, xor = nil, reflect = nil)
      @item_name = item_name
      @bit_offset = bit_offset
      @bit_size = bit_size
      case bit_size
      when 16
        @pack = 'n'
        @crc = Crc16.new()#poly, seed, xor, reflect)
      when 32
        @pack = 'N'
        @crc = Crc32.new()#poly, seed, xor, reflect)
      when 64
        @pack = 'NN'
        @crc = Crc64.new()#poly, seed, xor, reflect)
      else
        raise "Invalid bit size of #{bit_size}. Must be 16, 32, or 64."
      end
      @append_remove = append_remove
      @bad_strategy = bad_strategy
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
      if @append_remove == STRIP_ON_READ
        new_data = data.dup
        new_data = new_data[0...(@bit_offset/8)]
        new_data << data[end_range..-1] unless end_range == -1
        return new_data
      end
      return data
    end

    def write_packet(packet)
      if @item_name
        end_range = packet.get_item(@item_name).bit_offset / 8
        crc = @crc.calc(packet.buffer(false)[0...end_range])
        packet.write(@item_name, crc)
      end
      packet
    end

    def write_data(data)
      unless @item_name
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

    # def read_packet(packet)
    #   crc = packet.read(@item_name, :RAW)
    #   calculated_crc = @crc.calc(packet.buffer)
    #   if calculated_crc != crc
    #     Logger.error "Invalid CRC detected! Calculated 0x#{calculated_crc.to_s(16)} vs found 0x#{crc.to_s(16)}."
    #   end
    #   return packet
    # end
  end
end
