# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file implements a class to handle responses to limits state changes.

require 'cosmos/packets/limits_response'

class PacketLimitsResponse < Cosmos::LimitsResponse

  def call(packet, item, old_limits_state)
    case item.limits.state
    when :RED_HIGH
      cmd((9990 + Random.rand(10)).to_s, 'NOOP')
    end
  end

end
