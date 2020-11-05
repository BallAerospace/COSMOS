# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/interface_thread'

module Cosmos

  # Overrides the packet handling method in InterfaceThread to sends all
  # packets to {Commanding#send_command_to_interface}
  class RouterThread < InterfaceThread

    protected

    def handle_packet(packet)
      unless System.allow_router_commanding
        Logger.error "Router received command with router commanding disabled"
        return
      end

      # Start out assuming we will route to all associated interfaces
      interfaces = @interface.interfaces

      # Identified packets we may handle differently...
      if packet.identified?
        target = System.targets[packet.target_name.upcase]
        if target
          if target.interface
            # If target exists and has an interface we will only send the packet to that interface
            interfaces = [target.interface]
          else
            # If target exists and has no interface we will not send the packet anywhere
            interfaces = []
            Logger.warn "Received command for target with no interface: #{packet.target_name} #{packet.packet_name}"
          end
        end

        # Make sure identified packet exists
        begin
          System.commands.packet(packet.target_name, packet.packet_name)
        rescue
          Logger.warn "Received unknown identified command: #{packet.target_name} #{packet.packet_name}"

          # Clear identification
          packet.target_name = nil
          packet.packet_name = nil
        end
      end

      interfaces.each do |interface|
        if interface.connected?
          begin
            CmdTlmServer.commanding.send_command_to_interface(interface, packet)
          rescue Exception => err
            Logger.error "Error routing command from #{@interface.name} to interface #{interface.name}\n#{err.formatted}"
          end
        else
          Logger.error "Attempted to route command from #{@interface.name} to disconnected interface #{interface.name}"
        end
      end
    end

  end # class RouterThread

end # module Cosmos
