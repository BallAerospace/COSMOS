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
  class RouterTopics < Topic
    def self.receive_telemetry(router, scope:)
      topics = []
      topics << "#{scope}__CMDROUTER__#{router.name}"
      router.target_names.each do |target_name|
        System.telemetry.packets(target_name).each do |packet_name, packet|
          topics << "#{scope}__TELEMETRY__#{packet.target_name}__#{packet.packet_name}"
        end
      end
      while true
        Store.read_topics(topics) do |topic, msg_id, msg_hash, redis|
          result = yield topic, msg_hash
          if topic =~ /CMDROUTER/
            ack_topic = topic.split("__")
            ack_topic[1] = 'ACK' + ack_topic[1]
            ack_topic = ack_topic.join("__")
            Store.write_topic(ack_topic, { 'result' => result }, msg_id)
          end
        end
      end
    end

    def self.route_command(packet, target_names, scope:)
      if packet.identified?
        topic = "#{scope}__CMDTARGET__#{packet.target_name}"
        Store.write_topic(topic, { 'target_name' => packet.target_name, 'cmd_name' => packet.packet_name, 'cmd_buffer' => packet.buffer(false) })
      elsif target_names.length == 1
        topic = "#{scope}__CMDTARGET__#{target_names[0]}"
        Store.write_topic(topic, { 'target_name' => packet.target_name, 'cmd_name' => 'UNKNOWN', 'cmd_buffer' => packet.buffer(false) })
      else
        raise "No route for command: #{packet.target_name} #{packet.packet_name}"
      end
    end

  end
end