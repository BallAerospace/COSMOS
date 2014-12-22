# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'

module Cosmos

  # Converts the packet received count as a derived telemetry item
  class ReceivedCountConversion < Conversion

    # Initializes converted_type to :UINT and converted_bit_size to 32
    def initialize
      super()
      @converted_type = :UINT
      @converted_bit_size = 32
    end

    # @param (see Conversion#call)
    # @return [Integer] packet.received_count
    def call(value, packet, buffer)
      packet.received_count
    end

  end # class ReceivedCountConversion

end # module Cosmos
