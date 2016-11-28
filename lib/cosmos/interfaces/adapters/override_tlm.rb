# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module OverrideTlm
    def override_tlm_raw(target_name, packet_name, item_name, value)
      @override_tlm_raw ||= {}
      @override_tlm_raw[target_name] ||= {}
      @override_tlm_raw[target_name][packet_name] ||= {}
      @override_tlm_raw[target_name][packet_name][item_name] = value
    end

    def clear_override_tlm(target_name, packet_name, item_name)
      @override_tlm_raw ||= {}
      pkt = @override_tlm_raw[target_name]
      if pkt
        items = @override_tlm_raw[target_name][packet_name]
        items.delete(item_name) if items
      end
    end

    # Called to perform modifications on a read packet before it is given to the user
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def post_read_packet(packet)
      packet = super(packet)
      if @override_tlm_raw && !@override_tlm_raw.empty?
        packets = @override_tlm_raw[packet.target_name]
        if packets
          items = packets[packet.packet_name]
          if items
            items.each do |item_name, value|
              # This should be safe because we check at the API level it exists
              packet.write(item_name, value)
            end
          end
        end
      end
      packet
    end

  end
end

