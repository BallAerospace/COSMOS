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
  # LimitsEventTopic keeps track of not only the <SCOPE>__openc3_limits_events topic
  # but also the ancillary key value stores. The LIMITS_CHANGE event updates the
  # <SCOPE>__current_limits key. The LIMITS_SET event updates the <SCOPE>__limits_sets.
  # While this isn't a clean separation of topics (streams) and models (key-value)
  # it helps maintain consistency as the topic and model are linked.
  class LimitsEventTopic < Topic
    def self.write(event, scope:)
      case event[:type]
      when :LIMITS_CHANGE
        # The current_limits hash keeps only the current limits state of items
        # It is used by the API to determine the overall limits state
        field = "#{event[:target_name]}__#{event[:packet_name]}__#{event[:item_name]}"
        Store.hset("#{scope}__current_limits", field, event[:new_limits_state])

      when :LIMITS_SETTINGS
        # Limits updated in limits_api.rb to avoid circular reference to TargetModel
        unless sets(scope: scope).has_key?(event[:limits_set])
          Store.hset("#{scope}__limits_sets", event[:limits_set], 'false')
        end

      when :LIMITS_SET
        sets = sets(scope: scope)
        raise "Set '#{event[:set]}' does not exist!" unless sets.key?(event[:set])

        # Set all existing sets to "false"
        sets = sets.transform_values! { |_key, _value| "false" }
        sets[event[:set]] = "true" # Enable the requested set
        Store.hmset("#{scope}__limits_sets", *sets)
      else
        raise "Invalid limits event type '#{event[:type]}'"
      end

      Topic.write_topic("#{scope}__openc3_limits_events", event, '*', 1000)
    end

    def self.read(offset = nil, count: 100, scope:)
      topic = "#{scope}__openc3_limits_events"
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

    def self.out_of_limits(scope:)
      out_of_limits = []
      limits = Store.hgetall("#{scope}__current_limits")
      limits.each do |item, limits_state|
        if %w(RED RED_HIGH RED_LOW YELLOW YELLOW_HIGH YELLOW_LOW).include?(limits_state)
          target_name, packet_name, item_name = item.split('__')
          out_of_limits << [target_name, packet_name, item_name, limits_state]
        end
      end
      out_of_limits
    end

    # Returns all the limits sets as keys with the value 'true' or 'false'
    # where only the active set is 'true'
    #
    # @return [Hash{String => String}] Set name followed by 'true' if enabled else 'false'
    def self.sets(scope:)
      Store.hgetall("#{scope}__limits_sets")
    end

    def self.current_set(scope:)
      sets(scope: scope).key('true') || "DEFAULT"
    end

    def self.delete(_target_name, _packet_name, scope:)
      limits = Store.hgetall("#{scope}__current_limits")
      limits.each do |item, _limits_state|
        Store.hdel("#{scope}__current_limits", item)
      end
    end
  end
end
