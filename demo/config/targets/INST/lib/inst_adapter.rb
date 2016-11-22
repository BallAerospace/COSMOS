# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  module InstAdapter
    # Called to perform modifications on a read packet before it is given to the user
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def pre_write_packet(packet)
      packet = super(packet)
      flags = packet.read("CCSDSSEQFLAGS")
      Logger.info "Processing CCSDS Sequenced packets. Flags:#{flags}" if flags != 3
      packet
    end
  end
end

