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

  # Converts the packet received time object into a formatted string.
  class ReceivedTimeFormattedConversion < Conversion

    # Initializes converted_type to :STRING and converted_bit_size to 0
    def initialize
      super()
      @converted_type = :STRING
      @converted_bit_size = 0
    end

    # @param (see Conversion#call)
    # @return [String] Formatted packet time
    def call(value, packet, buffer)
      if packet.received_time
        return packet.received_time.formatted
      else
        return 'No Packet Received Time'
      end
    end

  end # class ReceivedTimeFormattedConversion

end # module Cosmos
