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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/utilities/store'

module OpenC3
  class Topic
    if RUBY_VERSION < "3"
      # Delegate all unknown class methods to delegate to the EphemeralStore
      def self.method_missing(message, *args, &block)
        EphemeralStore.public_send(message, *args, &block)
      end
    else
      # Delegate all unknown class methods to delegate to the EphemeralStore
      def self.method_missing(message, *args, **kwargs, &block)
        EphemeralStore.public_send(message, *args, **kwargs, &block)
      end
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

    def self.get_cnt(topic)
      _, packet = EphemeralStore.get_newest_message(topic)
      packet ? packet["received_count"].to_i : 0
    end
  end
end
