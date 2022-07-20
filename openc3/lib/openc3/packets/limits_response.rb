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

# This file implements a class to handle responses to limits state changes.

require 'openc3/api/api'

module OpenC3
  # This class defines a #call method which is called when a PacketItem
  # goes out of limits. This class must be subclassed and the call method
  # implemented. Do NOT use this class directly.
  class LimitsResponse
    include Api

    # @param packet [Packet] Packet the limits response is assigned to
    # @param item [PacketItem] PacketItem the limits response is assigned to
    # @param old_limits_state [Symbol] Previous value of the limit. One of nil,
    #   :GREEN_HIGH, :GREEN_LOW, :YELLOW, :YELLOW_HIGH, :YELLOW_LOW,
    #   :RED, :RED_HIGH, :RED_LOW. nil if the previous limit state has not yet
    #   been established.
    def call(packet, item, old_limits_state)
      raise "call method must be defined by subclass"
    end

    def to_s
      self.class.to_s.split('::')[-1]
    end

    def to_config
      "    LIMITS_RESPONSE #{self.class.name.class_name_to_filename}\n"
    end

    def as_json(*a)
      { "class" => self.class.name.to_s }
    end
  end # class LimitsResponse
end
