# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'thread'

module Cosmos
  # Adds a checksum to the end of the data before sending it over the
  # interface. When reading from the interface it expects the last word to be
  # the checksum.
  module ChecksumProtocol
    # Adds the checksum word to the data
    #
    # @param data [String] Raw packet data
    # @return [String] Packet data with checksum added
    def pre_write_data(data)
      data = super(data)
      checksum = 0xFFFF
      data.each_byte {|x| checksum += x }
      checksum &= 0xFFFF
      data << [checksum].pack("n") # 16 bit unsigned big endian
      data
    end

    # Determines if the checksum is correct before returning the data with the
    # checksum word removed.
    #
    # @param data [String] Raw packet data
    # @return [String|nil] Packet data with checksum word removed or nil if bad
    #   checksum
    def post_read_data(data)
      len = data.length
      calc_checksum = 0xFFFF
      data[0..(len - 3)].each_byte {|x| calc_checksum += x }
      calc_checksum &= 0xFFFF
      truth_checksum = data[-2..-1].unpack("n") # 16 bit unsigned big endian
      if truth_checksum == calc_checksum
        data[0..(len - 2)]
      else
        puts "Bad checksum detected. Calculated 0x#{calc_checksum.to_s(16)} but received 0x#{truth_checksum.to_s(16)}. Dropping packet."
        nil
      end
    end
  end
end
