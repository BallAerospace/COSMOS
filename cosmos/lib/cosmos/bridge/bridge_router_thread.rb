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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/tools/cmd_tlm_server/interface_thread'

module Cosmos
  class BridgeRouterThread < InterfaceThread
    protected

    def handle_packet(packet)
      @interface.interfaces.each do |interface|
        if interface.connected?
          if interface.write_allowed?
            begin
              interface.write(packet)
            rescue Exception => err
              Logger.error "Error routing command from #{@interface.name} to interface #{interface.name}\n#{err.formatted}"
            end
          end
        else
          Logger.error "Attempted to route command from #{@interface.name} to disconnected interface #{interface.name}"
        end
      end
    end
  end # class BridgeRouterThread
end # module Cosmos
