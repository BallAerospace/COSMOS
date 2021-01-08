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
  class CommandTopic < Topic
    def self.write_packet(packet, scope:)
      topic = "#{scope}__COMMAND__#{packet.target_name}__#{packet.packet_name}"
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
                  target_name: packet.target_name,
                  packet_name: packet.packet_name,
                  received_count: packet.received_count,
                  buffer: packet.buffer(false) }
      Store.write_topic(topic, msg_hash)
    end
  end
end