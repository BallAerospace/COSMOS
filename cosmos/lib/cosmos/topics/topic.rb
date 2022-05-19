# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

require 'cosmos/utilities/store'

module Cosmos
  class Topic
    def self.initialize_streams(topics)
      EphemeralStore.initialize_streams(topics)
    end

    def self.read_topics(topics, offsets = nil, timeout_ms = 1000, count = nil, &block)
      EphemeralStore.read_topics(topics, offsets, timeout_ms, count, &block)
    end

    def self.write_topic(topic, msg_hash, id = '*', maxlen = nil, approximate = true)
      EphemeralStore.write_topic(topic, msg_hash, id, maxlen, approximate)
    end

    def self.clear_topics(topics, maxlen = 0)
      topics.each { |topic| EphemeralStore.xtrim(topic, maxlen) }
    end

    def self.topics(scope, key)
      EphemeralStore
        .scan_each(match: "#{scope}__#{key}__*", type: 'stream', count: 100)
        .to_a # Change the enumerator into an array
        .uniq # Scan can return duplicates so ensure unique
        .sort # Sort not entirely necessary but nice
    end

    def self.get_oldest_message(topic)
      EphemeralStore.get_oldest_message(topic)
    end

    def self.get_newest_message(topic)
      EphemeralStore.get_newest_message(topic)
    end

    def self.trim_topic(topic, minid, approximate = true, limit: 0)
      EphemeralStore.trim_topic(topic, minid, approximate, limit: limit)
    end

    def self.update_topic_offsets(topics)
      EphemeralStore.update_topic_offsets(topics)
    end

    def self.del(topic)
      EphemeralStore.del(topic)
    end

    def self.get_cnt(topic)
      _, packet = EphemeralStore.get_newest_message(topic)
      packet ? packet["received_count"].to_i : 0
    end
  end
end
