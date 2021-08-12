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

require 'cosmos/conversions/conversion'

module Cosmos
  # Converts the packet received time into floating point seconds.
  class PacketTimeSecondsConversion < Conversion
    # Initializes converted_type to :FLOAT and converted_bit_size to 64
    def initialize
      super()
      @converted_type = :FLOAT
      @converted_bit_size = 64
    end

    # @param (see Conversion#call)
    # @return [Float] Packet received time in seconds
    def call(value, packet, buffer)
      packet_time = packet.packet_time
      if packet_time
        return packet_time.to_f
      else
        return 0.0
      end
    end
  end # class PacketTimeSecondsConversion
end # module Cosmos
