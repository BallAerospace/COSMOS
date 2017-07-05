# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module Script
    private

    def get_out_of_limits
      result = $cmd_tlm_server.get_out_of_limits
      result.each do |entry|
        entry[3] = entry[3].to_s.intern if entry[3]
      end
      result
    end

    def get_overall_limits_state(ignored_items = nil)
      return $cmd_tlm_server.get_overall_limits_state(ignored_items).to_s.intern
    end

    def limits_enabled?(*args)
      return $cmd_tlm_server.limits_enabled?(*args)
    end

    def enable_limits(*args)
      return $cmd_tlm_server.enable_limits(*args)
    end

    def disable_limits(*args)
      return $cmd_tlm_server.disable_limits(*args)
    end

    def get_stale(with_limits_only = false, target_name = nil)
      return $cmd_tlm_server.get_stale(with_limits_only, target_name)
    end

    def get_limits(target_name, packet_name, item_name, limits_set = nil)
      results = $cmd_tlm_server.get_limits(target_name, packet_name, item_name, limits_set)
      results[0] = results[0].to_s.intern if results[0]
      return results
    end

    def set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low = nil, green_high = nil, limits_set = :CUSTOM, persistence = nil, enabled = true)
      results = $cmd_tlm_server.set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low, green_high, limits_set, persistence, enabled)
      results[0] = results[0].to_s.intern if results[0]
      return results
    end

    def get_limits_groups
      return $cmd_tlm_server.get_limits_groups
    end

    def enable_limits_group(group_name)
      return $cmd_tlm_server.enable_limits_group(group_name)
    end

    def disable_limits_group(group_name)
      return $cmd_tlm_server.disable_limits_group(group_name)
    end

    def get_limits_sets
      result = $cmd_tlm_server.get_limits_sets
      result.each_with_index do |limits_set, index|
        result[index] = limits_set.to_s.intern
      end
      return result
    end

    def set_limits_set(limits_set)
      return $cmd_tlm_server.set_limits_set(limits_set)
    end

    def get_limits_set
      result = $cmd_tlm_server.get_limits_set
      # Limits sets are always represented as symbols
      result.to_s.intern
    end

    def subscribe_limits_events(queue_size = CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE)
      return $cmd_tlm_server.subscribe_limits_events(queue_size)
    end

    def unsubscribe_limits_events(id)
      return $cmd_tlm_server.unsubscribe_limits_events(id)
    end

    def get_limits_event(id, non_block = false)
      result = $cmd_tlm_server.get_limits_event(id, non_block)
      if result
        result[0] = result[0].to_s.intern
        if result[0] == :LIMITS_CHANGE
          result[1][3] = result[1][3].to_s.intern if result[1][3]
          result[1][4] = result[1][4].to_s.intern if result[1][4]
        elsif result[0] == :LIMITS_SETTINGS
          result[1][3] = result[1][3].to_s.intern if result[1][3]
        elsif result[0] == :STALE_PACKET
          # Nothing extra to do
        elsif result[0] == :STALE_PACKET_RCVD
          # Nothing extra to do
        else
          result[1] = result[1].to_s.intern
        end
      end
      result
    end

  end
end

