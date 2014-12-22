# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/packet'
require 'cosmos/packets/structure'
require 'cosmos/system/system'

module Cosmos

  # Update Packet for Simulated Targets
  class Packet < Structure
    attr_accessor :packet_rate
  end

  class SimulatedTarget

    attr_accessor :tlm_packets

    def initialize (target_name)
      @tlm_packets = {}

      #Generate copy of telemetry packets for this target
      System.telemetry.packets(target_name).each do |name, packet|
        @tlm_packets[name] = packet.clone
        @tlm_packets[name].enable_method_missing
      end

      #Set id values
      @tlm_packets.each do |name, packet|
        ids = packet.id_items
        ids.each do |id|
          packet.send((id.name + '=').to_sym, id.id_value)
        end
      end

      @current_cycle_delta = {}
    end

    def set_rates
      raise "Error: set_rates must be implemented by subclass"
    end

    def write(packet)
      raise "Error: write must be implemented by subclass"
    end

    def read(count_100hz, time)
      raise "Error: read must be implemented by subclass"
    end

    protected

    def set_rate(packet_name, rate)
      packet = @tlm_packets[packet_name.upcase]
      packet.packet_rate = rate if packet
    end

    def get_pending_packets(count_100hz)
      pending_packets = []

      #determine if packets are due to be sent and add to pending
      @tlm_packets.each do |name, packet|
        if packet.packet_rate
          if ((count_100hz % packet.packet_rate) == 0)
            pending_packets << packet
          end
        end
      end

      pending_packets
    end

    def cycle_tlm_item(packet, item_name, min, max, first_delta)
      packet_name = packet.packet_name
      @current_cycle_delta[packet_name] ||= {}
      @current_cycle_delta[packet_name][item_name] ||= first_delta

      current_delta = @current_cycle_delta[packet_name][item_name]
      current_value = packet.read(item_name)
      updated_value = current_value + current_delta
      if updated_value < min
        updated_value = min
        @current_cycle_delta[packet_name][item_name] = -current_delta
      elsif updated_value > max
        updated_value = max
        @current_cycle_delta[packet_name][item_name] = -current_delta
      end
      packet.write(item_name, updated_value)
    end
  end

end
