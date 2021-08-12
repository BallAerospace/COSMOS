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

require 'cosmos/interfaces/protocols/protocol'

module Cosmos
  # Protocol which permanently overrides an item value such that reading the
  # item returns the overriden value. Methods are prefixed with underscores
  # so the API can include the original name which calls out to these
  # methods. Clearing the override requires calling normalize_tlm.
  class OverrideProtocol < Protocol
    # @param allow_empty_data [true/false/nil] See Protocol#initialize
    def initialize(allow_empty_data = nil)
      super(allow_empty_data)
    end

    # Called to perform modifications on a read packet before it is given to the user
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def read_packet(packet)
      if @interface.override_tlm && !@interface.override_tlm.empty?
        # Need to make sure packet is identified and defined
        target_names = nil
        target_names = @interface.target_names if @interface
        identified_packet = System.telemetry.identify_and_define_packet(packet, target_names)
        if identified_packet
          packet = identified_packet
          packets = @interface.override_tlm[packet.target_name]
          if packets
            items = packets[packet.packet_name]
            if items
              items.each do |item_name, value|
                # This should be safe because we check at the API level it exists
                packet.write(item_name, value[0], value[1])
              end
            end
          end
        end
      end
      return packet
    end
  end
end
