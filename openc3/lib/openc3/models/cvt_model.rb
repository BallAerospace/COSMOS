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
  class CvtModel
    VALUE_TYPES = [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS]
    # Stores telemetry item overrides which are returned on every request to get_item
    @overrides = {}

    def self.build_json_from_packet(packet)
      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash["#{item.name}__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
        json_hash["#{item.name}__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash["#{item.name}__U"] = packet.read_item(item, :WITH_UNITS) if item.units
        limits_state = item.limits.state
        json_hash["#{item.name}__L"] = limits_state if limits_state
      end
      json_hash
    end

    # Delete the current value table for a target
    def self.del(target_name:, packet_name:, scope:)
      EphemeralStore.hdel("#{scope}__tlm__#{target_name}", packet_name)
    end

    # Set the current value table for a target, packet
    def self.set(hash, target_name:, packet_name:, scope:)
      EphemeralStore.hset("#{scope}__tlm__#{target_name}", packet_name, JSON.generate(hash.as_json(:allow_nan => true)))
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
      hash = JSON.parse(EphemeralStore.hget("#{scope}__tlm__#{target_name}", packet_name), :allow_nan => true, :create_additions => true)
      hash[field] = value
      EphemeralStore.hset("#{scope}__tlm__#{target_name}", packet_name, JSON.generate(hash.as_json(:allow_nan => true)))
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
      hash = JSON.parse(EphemeralStore.hget("#{scope}__tlm__#{target_name}", packet_name), :allow_nan => true, :create_additions => true)
      hash.values_at(*types).each do |result|
        return result if result
      end
      return nil
    end

    # Return all item values and limit state from the CVT
    #
    # @param items [Array<String>] Items to return. Must be formatted as TGT__PKT__ITEM__TYPE
    # @return [Array] Array of values
    def self.get_tlm_values(items, scope: $openc3_scope)
      results = []
      lookups = []
      packet_lookup = {}
      # First generate a lookup hash of all the items represented so we can query the CVT
      items.each { |item| _parse_item(lookups, item) }

      lookups.each do |target_packet_key, target_name, packet_name, packet_values|
        unless packet_lookup[target_packet_key]
          packet = EphemeralStore.hget("#{scope}__tlm__#{target_name}", packet_name)
          raise "Packet '#{target_name} #{packet_name}' does not exist" unless packet
          packet_lookup[target_packet_key] = JSON.parse(packet, :allow_nan => true, :create_additions => true)
        end
        hash = packet_lookup[target_packet_key]
        item_result = []
        packet_values.each do |value|
          item_result[0] = hash[value]
          break if item_result[0] # We want the first value
        end
        # If we were able to find a value, try to get the limits state
        if item_result[0]
          # The last key is simply the name (RAW) so we can append __L
          # If there is no limits then it returns nil which is acceptable
          item_result[1] = hash["#{packet_values[-1]}__L"]
          item_result[1] = item_result[1].intern if item_result[1] # Convert to symbol
        else
          raise "Item '#{target_name} #{packet_name} #{packet_values[-1]}' does not exist" unless hash.key?(packet_values[-1])
          item_result[1] = nil
        end
        results << item_result
      end
      results
    end

    # Override a current value table item such that it always returns the same value
    # for the given type
    def self.override(target_name, packet_name, item_name, value, type:, scope: $openc3_scope)
      if VALUE_TYPES.include?(type)
        @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"] = value
      else
        raise "Unknown type '#{type}' for #{target_name} #{packet_name} #{item_name}"
      end
    end

    # Normalize a current value table item such that it returns the actual value
    def self.normalize(target_name, packet_name, item_name, type: :ALL, scope: $openc3_scope)
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

    # PRIVATE METHODS

    def self._parse_item(lookups, item)
      # parse item and update lookups with packet_name and target_name and keys
      #
      # return an ordered array of hash with keys
      target_name, packet_name, item_name, value_type = item.split('__')
      raise ArgumentError, "items must be formatted as TGT__PKT__ITEM__TYPE" if target_name.nil? || packet_name.nil? || item_name.nil? || value_type.nil?

      # We build lookup keys by including all the less formatted types to gracefully degrade lookups
      # This allows the user to specify WITH_UNITS and if there is no conversions it will simply return the RAW value
      case value_type.upcase
      when 'RAW'
        keys = [item_name]
      when 'CONVERTED'
        keys = ["#{item_name}__C", item_name]
      when 'FORMATTED'
        keys = ["#{item_name}__F", "#{item_name}__C", item_name]
      when 'WITH_UNITS'
        keys = ["#{item_name}__U", "#{item_name}__F", "#{item_name}__C", item_name]
      else
        raise "Unknown value type #{value_type}"
      end
      lookups << ["#{target_name}__#{packet_name}", target_name, packet_name, keys]
    end
  end
end
