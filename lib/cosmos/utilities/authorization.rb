# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module Authorization
    private

    # Raises an exception if unauthorized, otherwise does nothing
    def authorize(permission: nil, target_name: nil, packet_name: nil, interface_name: nil, router_name: nil, scope: nil, token: nil)
      raise "Scope is required" unless scope
    end

  end # module Authorization

end # module Cosmos
