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
require 'cosmos/models/target_model'

module Cosmos
  # LimitsEventTopic keeps track of not only the <SCOPE>__cosmos_limits_events topic
  # but also the ancillary key value stores. The LIMITS_CHANGE event updates the
  # <SCOPE>__current_limits key. The LIMITS_SETTINGS event changes the limits
  # settings on a particular item. The LIMITS_SET event updates the <SCOPE>__limits_sets.
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
        packet = TargetModel.packet(event[:target_name], event[:packet_name], scope: scope)
        found_item = nil
        packet['items'].each do |item|
          if item['name'] == event[:item_name]
            item['limits']['persistence_setting'] = event[:persistence]
            if event[:enabled]
              item['limits']['enabled'] = true
            else
              item['limits'].delete('enabled')
            end
            limits = {}
            limits['red_low'] = event[:red_low]
            limits['yellow_low'] = event[:yellow_low]
            limits['yellow_high'] = event[:yellow_high]
            limits['red_high'] = event[:red_high]
            limits['green_low'] = event[:green_low] if event[:green_low]
            limits['green_high'] = event[:green_high] if event[:green_high]
            item['limits'][event[:limits_set]] = limits
            found_item = item
            break
          end
        end
        raise "Item '#{event[:target_name]} #{event[:packet_name]} #{event[:item_name]}' does not exist" unless found_item
        TargetModel.set_packet(event[:target_name], event[:packet_name], packet, scope: scope)

      when :LIMITS_SET
        sets = sets(scope: scope)
        raise "Set '#{event[:set]}' does not exist!" unless sets.key?(event[:set])
        # Set all existing sets to "false"
        sets = sets.transform_values!{ |key, value| "false" }
        sets[event[:set]] = "true" # Enable the requested set
        Store.hmset("#{scope}__limits_sets", *sets)
      else
        raise "Invalid limits event type '#{event[:type]}'"
      end

      Store.write_topic("#{scope}__cosmos_limits_events", event)
    end

    def self.read(offset = nil, count: 100, scope:)
      topic = "#{scope}__cosmos_limits_events"
      if offset
        result = Store.xread(topic, offset, count: count)
        if result.empty?
          [] # We want to return an empty array rather than an empty hash
        else
          # result is a hash with the topic key followed by an array of results
          # This returns just the array of arrays [[offset, hash], [offset, hash], ...]
          result[topic]
        end
      else
        Store.xrevrange(topic, count: 1)
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

    def self.delete(target_name, packet_name, scope:)
      fields = []
      limits = Store.hgetall("#{scope}__current_limits")
      limits.each do |item, limits_state|
        fields << item if item.include?("#{target_name}__#{packet_name}")
      end
      Store.hdel(fields)
    end
  end
end
