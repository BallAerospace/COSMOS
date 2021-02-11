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

require 'cosmos/packets/packet_config'

module Cosmos

  # Limits uses PacketConfig to parse the command and telemetry
  # configuration files. It provides the API layer which other classes use to
  # access information about and manipulate limits. This includes getting,
  # setting and checking individual limit items as well as manipulating limits
  # groups.
  class Limits
    attr_reader :config

    LATEST_PACKET_NAME = 'LATEST'.freeze

    # @param config [PacketConfig] Packet configuration to use to access the
    #   limits information
    def initialize(config)
      @config = config
    end

    # (see PacketConfig#warnings)
    def warnings
      return @config.warnings
    end

    # (see PacketConfig#limits_sets)
    def sets
      return @config.limits_sets
    end

    # @param config [PacketConfig] Set the packet configuration to a new
    #   configuration. This will change everything this class returns!
    def config=(config)
      @config = config
    end

    # (see Cosmos::Packet#out_of_limits)
    def out_of_limits
      items = []
      @config.telemetry.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          new_items = packet.out_of_limits
          items.concat(new_items)
        end
      end
      return items
    end

    # @param ignored_items [Array<Array<String, String, String>>] Items to ignore from the consideration
    # @return [Symbol] The overall limits state for the system
    def overall_limits_state(ignored_items = nil)
      overall = :GREEN
      limits_packet_stale = false
      items_out_of_limits = []
      # Note: If anything with limits is stale then overall limits state cannot be green or blue
      @config.telemetry.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          if packet.stale && !packet.limits_items.empty?
            if ignored_items
              all_ignored = true
              packet.limits_items.each do |item|
                all_ignored = false unless includes_item?(ignored_items, target_name, packet_name, item.name)
              end
            else
              all_ignored = false
            end
            limits_packet_stale = true unless all_ignored
          end
          items_out_of_limits.concat(packet.out_of_limits)
        end
      end
      items_out_of_limits.each do |target_name, packet_name, item_name, limits_state|
        next if ignored_items && includes_item?(ignored_items, target_name, packet_name, item_name)
        case overall
        # If our overall state is currently blue or green we can go to any state
        when :BLUE, :GREEN, :GREEN_HIGH, :GREEN_LOW
          overall = limits_state
        # If our overal state is yellow we can only go higher to red
        when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
          if limits_state == :RED || limits_state == :RED_HIGH || limits_state == :RED_LOW
            overall = limits_state
            break # Red is as high as we go so no need to look for more
          end
        end
      end
      overall = :GREEN if overall == :GREEN_HIGH || overall == :GREEN_LOW || overall == :BLUE
      overall = :YELLOW if overall == :YELLOW_HIGH || overall == :YELLOW_LOW
      overall = :RED if overall == :RED_HIGH || overall == :RED_LOW
      overall = :STALE if (overall == :GREEN || overall == :BLUE) && limits_packet_stale
      return overall
    end

    # @return [Hash(String, Array)] The defined limits groups
    def groups
      return @config.limits_groups
    end

    # Enables limit checking for all the items in the given group.
    #
    # @param group_name [String] Name of the group to enable
    def enable_group(group_name)
      group_upcase = group_name.to_s.upcase
      limits_group = @config.limits_groups[group_upcase]
      if limits_group
        limits_group.each do |target_name, packet_name, item_name|
          enable(target_name, packet_name, item_name)
        end
      else
        raise "LIMITS_GROUP #{group_upcase} undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP #{group_upcase}"
      end
    end

    # Disables limit checking for all the items in the given group.
    #
    # @param group_name [String] Name of the group to disable
    def disable_group(group_name)
      group_upcase = group_name.to_s.upcase
      limits_group = @config.limits_groups[group_upcase]
      if limits_group
        limits_group.each do |target_name, packet_name, item_name|
          disable(target_name, packet_name, item_name)
        end
      else
        raise "LIMITS_GROUP #{group_upcase} undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP #{group_upcase}"
      end
    end

    # Checks whether the limits are enabled for the specified item
    #
    # @param target_name [String] The target name
    # @param packet_name [String] The packet name. Must be a defined packet name and not 'LATEST'.
    # @param item_name [String] The item name
    def enabled?(target_name, packet_name, item_name)
      get_packet(target_name, packet_name).get_item(item_name).limits.enabled
    end

    # Enables limit checking for the specified item
    #
    # @param (see #enabled?)
    def enable(target_name, packet_name, item_name)
      get_packet(target_name, packet_name).enable_limits(item_name)
    end

    # Disables limit checking for the specified item
    #
    # @param (see #enabled?)
    def disable(target_name, packet_name, item_name)
      get_packet(target_name, packet_name).disable_limits(item_name)
    end

    # Get the limits for a telemetry item
    #
    # @param target_name [String] Target Name
    # @param packet_name [String] Packet Name
    # @param item_name [String] Item Name
    # @param limits_set [String or Symbol or nil] Desired Limits set.  nil = current limits set
    # @return [Array<limits_set, persistence, enabled, red_low, yellow_low, red_high, yellow_high, green_low (optional), green_high (optional)] Limits information
    def get(target_name, packet_name, item_name, limits_set = nil)
      limits = get_packet(target_name, packet_name).get_item(item_name).limits
      if limits.values
        if limits_set
          limits_set = limits_set.to_s.upcase.intern
        else
          limits_set = System.limits_set
        end
        limits_for_set = limits.values[limits_set]
        if limits_for_set
          return [limits_set, limits.persistence_setting, limits.enabled, limits_for_set[0], limits_for_set[1], limits_for_set[2], limits_for_set[3], limits_for_set[4], limits_for_set[5]]
        else
          return [nil, nil, nil, nil, nil, nil, nil, nil, nil]
        end
      else
        return [nil, nil, nil, nil, nil, nil, nil, nil, nil]
      end
    end

    # Set the limits for a telemetry item
    #
    # @param target_name [String] Target Name
    # @param packet_name [String] Packet Name
    # @param item_name [String] Item Name
    # @param red_low [Float] Red Low Limit
    # @param yellow_low [Float] Yellow Low Limit
    # @param yellow_high [Float] Yellow High Limit
    # @param red_high [Float] Red High Limit
    # @param green_low [Float] Green Low Limit
    # @param green_high [Float] Green High Limit
    # @param limits_set [String or Symbol or nil] Desired Limits set.  nil = current limits set, recommend using :CUSTOM
    # @param persistence [Integer] The number of samples the value must be out of limits before detecting a limits change. nil = Leave unchanged
    # @param enabled [Boolean] If limits monitoring is enabled for this item
    # @return [Array<limits_set, persistence, enabled, red_low, yellow_low, red_high, yellow_high, green_low (optional), green_high (optional)] Limits information
    def set(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low = nil, green_high = nil, limits_set = :CUSTOM, persistence = nil, enabled = true)
      packet = get_packet(target_name, packet_name)
      item = packet.get_item(item_name)
      limits = item.limits
      if limits_set
        limits_set = limits_set.to_s.upcase.intern
      else
        limits_set = System.limits_set
      end
      if !limits.values
        if limits_set == :DEFAULT
          limits.values = {:DEFAULT => []}
        else
          raise "DEFAULT limits must be defined for #{target_name} #{packet_name} #{item_name} before setting limits set #{limits_set}"
        end
      end
      limits_for_set = limits.values[limits_set]
      unless limits_for_set
        limits.values[limits_set] = []
        limits_for_set = limits.values[limits_set]
      end
      limits_for_set[0] = red_low.to_f
      limits_for_set[1] = yellow_low.to_f
      limits_for_set[2] = yellow_high.to_f
      limits_for_set[3] = red_high.to_f
      limits_for_set.delete_at(5) if limits_for_set[5]
      limits_for_set.delete_at(4) if limits_for_set[4]
      if green_low && green_high
        limits_for_set[4] = green_low.to_f
        limits_for_set[5] = green_high.to_f
      end
      limits.enabled = enabled
      limits.persistence_setting = Integer(persistence) if persistence
      packet.update_limits_items_cache(item)
      @config.limits_sets << limits_set
      @config.limits_sets.uniq!
      return [limits_set, limits.persistence_setting, limits.enabled, limits_for_set[0], limits_for_set[1], limits_for_set[2], limits_for_set[3], limits_for_set[4], limits_for_set[5]]
    end

    protected

    def get_packet(target_name, packet_name)
      raise "LATEST packet not valid" if packet_name.upcase == LATEST_PACKET_NAME
      packets = @config.telemetry[target_name.to_s.upcase]
      raise "Telemetry target '#{target_name.to_s.upcase}' does not exist" unless packets
      packet = packets[packet_name.to_s.upcase]
      raise "Telemetry packet '#{target_name.to_s.upcase} #{packet_name.to_s.upcase}' does not exist" unless packet
      return packet
    end

    def includes_item?(ignored_items, target_name, packet_name, item_name)
      ignored_items.each do |array_target_name, array_packet_name, array_item_name|
        if ((array_target_name == target_name) &&
            (array_packet_name == packet_name) &&
            # If the item name is nil we're ignoring an entire packet
            (array_item_name == item_name || array_item_name.nil?))
          return true
        end
      end
      return false
    end
  end
end
