# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/interface_microservice'

module Cosmos
  class RouterMicroservice < InterfaceMicroservice

    def handle_packet(packet)
      @count += 1
      RouterStatusModel.set(@interface.as_json, scope: @scope)
      if !packet.identified?
        # Need to identify so we can find the target
        identified_packet = System.commands.identify(packet.buffer(false), @target_names)
        packet = identified_packet if identified_packet
      end

      begin
        RouterTopics.route_command(packet, @target_names, scope: @scope)
        @count += 1
      rescue Exception => err
        @error = err
        Logger.error "Error routing command from #{@interface.name}\n#{err.formatted}"
      end
    end

  end
end

Cosmos::RouterMicroservice.run if __FILE__ == $0
