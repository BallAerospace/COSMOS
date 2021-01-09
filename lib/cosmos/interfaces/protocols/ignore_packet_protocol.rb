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

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/protocol'
require 'cosmos/utilities/crc'
require 'thread'

module Cosmos
  # Ignore a specific packet by not letting it through the protocol
  class IgnorePacketProtocol < Protocol
    # @param target_name [String] Target name
    # @param packet_name [String] Packet name
    def initialize(target_name, packet_name, allow_empty_data = nil)
      super(allow_empty_data)
      System.telemetry.packet(target_name, packet_name)
      @target_name = target_name
      @packet_name = packet_name
    end

    def read_packet(packet)
      # Need to make sure packet is identified and defined
      target_names = nil
      target_names = @interface.target_names if @interface
      identified_packet = System.telemetry.identify_and_define_packet(packet, target_names)
      if identified_packet
        if identified_packet.target_name == @target_name && identified_packet.packet_name == @packet_name
          return :STOP
        end
      end
      return super(packet)
    end

    def write_packet(packet)
      return :STOP if packet.target_name == @target_name && packet.packet_name == @packet_name
      return super(packet)
    end
  end
end
