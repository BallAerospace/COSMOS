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

require 'openc3/topics/topic'

module OpenC3
  class ConfigTopic < Topic
    PRIMARY_KEY = "__CONFIG"

    # Helper method to initialize the stream and ensure a consistent key
    def self.initialize_stream(scope)
      self.initialize_streams(["#{scope}#{PRIMARY_KEY}"])
    end

    # Write a configuration change to the topic
    # @param config [Hash] Hash with required keys 'kind', 'name', 'type'
    def self.write(config, scope:)
      unless config.keys.include?(:kind)
        raise "ConfigTopic error, required key kind: not given"
      end
      unless ['created', 'deleted'].include?(config[:kind])
        raise "ConfigTopic error unknown kind: #{config[:kind]}"
      end
      unless config.keys.include?(:name)
        raise "ConfigTopic error, required key name: not given"
      end
      unless config.keys.include?(:type)
        raise "ConfigTopic error, required key type: not given"
      end
      # Limit the configuration topics to 1000 entries
      Topic.write_topic("#{scope}#{PRIMARY_KEY}", config, '*', 1000)
    end

    def self.read(offset = nil, count: 100, scope:)
      topic = "#{scope}#{PRIMARY_KEY}"
      if offset
        result = Topic.read_topics([topic], [offset], nil, count)
        if result.empty?
          [] # We want to return an empty array rather than an empty hash
        else
          # result is a hash with the topic key followed by an array of results
          # This returns just the array of arrays [[offset, hash], [offset, hash], ...]
          result[topic]
        end
      else
        result = Topic.get_newest_message(topic)
        return [result] if result
        return []
      end
    end
  end
end
