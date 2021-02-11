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

require 'cosmos/utilities/store'

module Cosmos
  class CvtModel
    VALUE_TYPES = [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS]
    # Stores telemetry item overrides which are returned on every request to get_item
    @overrides = {}

    # Set multiple items in the current value table using the hash
    def self.set(hash, target_name:, packet_name:, scope:)
      Store.mapped_hmset("#{scope}__tlm__#{target_name}__#{packet_name}", hash)
    end

    # Set an item in the current value table
    def self.set_item(target_name, packet_name, item_name, value, type:, scope:)
      case type
      when :WITH_UNITS
        field = "#{item_name}__U"
      when :FORMATTED
        field = "#{item_name}__F"
      when :CONVERTED
        field = "#{item_name}__C"
      when :RAW
        field = item_name
      else
        raise "Unknown type '#{type}' for #{target_name} #{packet_name} #{item_name}"
      end
      Store.hset("#{scope}__tlm__#{target_name}__#{packet_name}", field, JSON.generate(value.as_json))
    end

    # Get an item from the current value table
    def self.get_item(target_name, packet_name, item_name, type:, scope:)
      if @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"]
        return @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"]
      end

      types = []
      case type
      when :WITH_UNITS
        types = ["#{item_name}__U", "#{item_name}__F", "#{item_name}__C", item_name]
      when :FORMATTED
        types = ["#{item_name}__F", "#{item_name}__C", item_name]
      when :CONVERTED
        types = ["#{item_name}__C", item_name]
      when :RAW
        types = [item_name]
      else
        raise "Unknown type '#{type}' for #{target_name} #{packet_name} #{item_name}"
      end

      results = Store.hmget("#{scope}__tlm__#{target_name}__#{packet_name}", *types)
      results.each do |result|
        return JSON.parse(result) if result
      end
      return nil
    end

    # Override a current value table item such that it always returns the same value
    # for the given type
    def self.override(target_name, packet_name, item_name, value, type:, scope: $cosmos_scope)
      if VALUE_TYPES.include?(type)
        @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"] = value
      else
        raise "Unknown type '#{type}' for #{target_name} #{packet_name} #{item_name}"
      end
    end

    # Normalize a current value table item such that it returns the actual value
    def self.normalize(target_name, packet_name, item_name, type: :ALL, scope: $cosmos_scope)
      if type == :ALL
        VALUE_TYPES.each do |type|
          @overrides.delete("#{target_name}__#{packet_name}__#{item_name}__#{type}")
        end
      else
        if VALUE_TYPES.include?(type)
          @overrides.delete("#{target_name}__#{packet_name}__#{item_name}__#{type}")
        else
          raise "Unknown type '#{type}' for #{target_name} #{packet_name} #{item_name}"
        end
      end
    end
  end
end
