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
  class InterfaceTopics < Topic
    def self.receive_commands(interface, scope:)
      topics = []
      topics << "#{scope}__CMDINTERFACE__#{interface.name}"
      interface.target_names.each do |target_name|
        topics << "#{scope}__CMDTARGET__#{target_name}"
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
  end
end