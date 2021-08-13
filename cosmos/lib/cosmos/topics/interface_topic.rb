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
  class InterfaceTopic < Topic
    def self.receive_commands(interface, scope:)
      topics = []
      topics << "{#{scope}__CMD}INTERFACE__#{interface.name}"
      interface.target_names.each do |target_name|
        topics << "{#{scope}__CMD}TARGET__#{target_name}"
      end
      while true
        Store.read_topics(topics) do |topic, msg_id, msg_hash, redis|
          result = yield topic, msg_hash
          ack_topic = topic.split("__")
          ack_topic[1] = 'ACK' + ack_topic[1]
          ack_topic = ack_topic.join("__")
          Store.write_topic(ack_topic, { 'result' => result, 'id' => msg_id })
        end
      end
    end

    def self.write_raw(interface_name, data, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'raw' => data })
    end

    def self.connect_interface(interface_name, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'connect' => 'true' })
    end

    def self.disconnect_interface(interface_name, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'disconnect' => 'true' })
    end

    def self.start_raw_logging(interface_name, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'log_raw' => 'true' })
    end

    def self.stop_raw_logging(interface_name, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'log_raw' => 'false' })
    end

    def self.shutdown(interface_name, scope:)
      Store.write_topic("{#{scope}__CMD}INTERFACE__#{interface_name}", { 'shutdown' => 'true' })
    end
  end
end
