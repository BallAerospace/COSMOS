# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/topics/topic'

module Cosmos
  class CommandDecomTopic < Topic
    def self.write_packet(packet, scope:)
      topic = "#{scope}__DECOMCMD__#{packet.target_name}__#{packet.packet_name}"
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
                  target_name: packet.target_name,
                  packet_name: packet.packet_name,
                  received_count: packet.received_count }
      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.write_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
      end
      msg_hash['json_data'] = JSON.generate(json_hash.as_json)
      Store.write_topic(topic, msg_hash)
    end
  end
end