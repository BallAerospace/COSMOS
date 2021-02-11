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

    def self.connect_router(router_name, scope:)
      Store.write_topic("#{scope}__CMDROUTER__#{router_name}", {'connect' => 'true'})
    end

    def self.disconnect_router(router_name, scope:)
      Store.write_topic("#{scope}__CMDROUTER__#{router_name}", {'disconnect' => 'true'})
    end

    def self.start_raw_logging(router_name, scope:)
      Store.write_topic("#{scope}__CMDROUTER__#{router_name}", {'log_raw' => 'true'})
    end

    def self.stop_raw_logging(router_name, scope:)
      Store.write_topic("#{scope}__CMDROUTER__#{router_name}", {'log_raw' => 'false'})
    end
  end
end
