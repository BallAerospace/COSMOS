# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # Protocol which permanently overrides an item value such that reading the
  # item returns the overriden value. Methods are prefixed with underscores
  # so the API can include the original name which calls out to these
  # methods. Clearing the override requires calling normalize_tlm.
  module OverrideProtocol
    def _override_tlm(target_name, packet_name, item_name, value)
      _override(target_name, packet_name, item_name, value, :CONVERTED)
    end

    def _override_tlm_raw(target_name, packet_name, item_name, value)
      _override(target_name, packet_name, item_name, value, :RAW)
    end

    def _normalize_tlm(target_name, packet_name, item_name)
      @override_tlm||= {}
      pkt = @override_tlm[target_name]
      if pkt
        items = @override_tlm[target_name][packet_name]
        items.delete(item_name) if items
      end
    end

    # Called to perform modifications on a read packet before it is given to the user
    #
    # @param packet [Packet] Original packet
    # @return [Packet] Potentially modified packet
    def post_read_packet(packet)
      packet = super(packet)
      if @override_tlm && !@override_tlm.empty?
        packets = @override_tlm[packet.target_name]
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
      packet
    end

    protected

    def _override(target_name, packet_name, item_name, value, type)
      @override_tlm||= {}
      @override_tlm[target_name] ||= {}
      @override_tlm[target_name][packet_name] ||= {}
      @override_tlm[target_name][packet_name][item_name] = [value, type]
    end
  end
end
