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

module OpenC3
  module Script
    private

    # Define all the modification methods such that we can disconnect them
    %i(enable_limits disable_limits set_limits enable_limits_group disable_limits_group set_limits_set).each do |method_name|
      define_method(method_name) do |*args|
        if $disconnect
          Logger.info "DISCONNECT: #{method_name}(#{args}) ignored"
        else
          $api_server.public_send(method_name, *args)
        end
      end
    end

    def get_limits_events(offset = nil, count: 100)
      result = $api_server.get_limits_events(offset, count: count)
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
