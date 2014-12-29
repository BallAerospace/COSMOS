# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'

module Cosmos

  # Converts the packet received time into floating point seconds.
  class ReceivedTimeSecondsConversion < Conversion

    # Initializes converted_type to :FLOAT and converted_bit_size to 64
    def initialize
      super()
      @converted_type = :FLOAT
      @converted_bit_size = 64
    end

    # @param (see Conversion#call)
    # @return [Float] Packet received time in seconds
    def call(value, packet, buffer)
      if packet.received_time
        return packet.received_time.to_f
      else
        return 0.0
      end
    end

  end # class ReceivedTimeSecondsConversion

end # module Cosmos
