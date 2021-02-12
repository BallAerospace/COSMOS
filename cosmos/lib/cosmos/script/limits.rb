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
      if $disconnect
        Logger.info "DISCONNECT: enable_limits(#{args}) ignored"
      else
        return $cmd_tlm_server.enable_limits(*args)
      end
    end

    def disable_limits(*args)
      if $disconnect
        Logger.info "DISCONNECT: enable_limits(#{args}) ignored"
      else
        return $cmd_tlm_server.disable_limits(*args)
      end
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
      if $disconnect
        Logger.info "DISCONNECT: set_limits(#{target_name}, #{packet_name}, #{item_name}, #{red_low}, #{yellow_low}, #{yellow_high}, #{red_high}, #{green_low}, #{green_high}, #{limits_set}, #{persistence}, #{enabled}) ignored"
      else
        results = $cmd_tlm_server.set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low, green_high, limits_set, persistence, enabled)
        results[0] = results[0].to_s.intern if results[0]
        return results
      end
    end

    def get_limits_groups
      return $cmd_tlm_server.get_limits_groups
    end

    def enable_limits_group(group_name)
      if $disconnect
        Logger.info "DISCONNECT: enable_limits_group(#{group_name}) ignored"
      else
        return $cmd_tlm_server.enable_limits_group(group_name)
      end
    end

    def disable_limits_group(group_name)
      if $disconnect
        Logger.info "DISCONNECT: enable_limits_group(#{group_name}) ignored"
      else
        return $cmd_tlm_server.disable_limits_group(group_name)
      end
    end

    def get_limits_sets
      result = $cmd_tlm_server.get_limits_sets
      result.each_with_index do |limits_set, index|
        result[index] = limits_set.to_s.intern
      end
      return result
    end

    def set_limits_set(limits_set)
      if $disconnect
        Logger.info "DISCONNECT: set_limits_set(#{limits_set}) ignored"
      else
        return $cmd_tlm_server.set_limits_set(limits_set)
      end
    end

    def get_limits_set
      result = $cmd_tlm_server.get_limits_set
      # Limits sets are always represented as symbols
      result.to_s.intern
    end

    def get_limits_events(offset = nil, count: 100)
      result = $cmd_tlm_server.get_limits_events(offset, count: count)
      if result
        result[0] = result[0].to_s.intern
        if result[0] == :LIMITS_CHANGE
          result[1][3] = result[1][3].to_s.intern if result[1][3]
          result[1][4] = result[1][4].to_s.intern if result[1][4]
          if result[1][5] and result[1][6]
            result[1][5] = Time.at(result[1][5], result[1][6]).sys
            result[1].delete_at(6)
          end
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
