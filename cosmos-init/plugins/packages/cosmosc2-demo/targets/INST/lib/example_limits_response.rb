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

# This file implements a class to handle responses to limits state changes.

require 'cosmos/packets/limits_response'

# ExampleLimitsResponse class
#
# This class handles a limits response
#
class ExampleLimitsResponse < Cosmos::LimitsResponse

  def call(packet, item, old_limits_state)
    case item.limits.state
    when :RED_HIGH
      cmd('<%= target_name %>', 'COLLECT', 'TYPE' => 'NORMAL', 'DURATION' => 5, scope: 'DEFAULT')
    when :RED_LOW
      cmd_no_hazardous_check('<%= target_name %>', 'CLEAR', scope: 'DEFAULT')
    end
  end

end # class ExampleLimitsResponse
