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
      Store.initialize_streams(topics)
    end

    def self.read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
      Store.read_topics(topics, offsets, timeout_ms, &block)
    end

    def self.clear_topics(topics, maxlen = 0)
      topics.each do |topic|
        Store.xtrim(topic, maxlen)
      end
    end

    def self.topics(scope, key)
      topics = []
      loop do
        token, streams = Store.scan(0, :match => "#{scope}__#{key}__*", :count => 1000)
        topics.concat(streams)
        break if token == 0
      end
      topics
    end
  end
end
