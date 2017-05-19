# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module Script
    private

    # Poll for the converted value of a telemetry item
    # Usage:
    #   tlm(target_name, packet_name, item_name)
    # or
    #   tlm('target_name packet_name item_name')
    def tlm(*args)
      return $cmd_tlm_server.tlm(*args)
    end

    # Poll for the raw value of a telemetry item
    # Usage:
    #   tlm_raw(target_name, packet_name, item_name)
    # or
    #   tlm_raw('target_name packet_name item_name')
    def tlm_raw(*args)
      return $cmd_tlm_server.tlm_raw(*args)
    end

    # Poll for the formatted value of a telemetry item
    # Usage:
    #   tlm_formatted(target_name, packet_name, item_name)
    # or
    #   tlm_formatted('target_name packet_name item_name')
    def tlm_formatted(*args)
      return $cmd_tlm_server.tlm_formatted(*args)
    end

    # Poll for the formatted with units value of a telemetry item
    # Usage:
    #   tlm_with_units(target_name, packet_name, item_name)
    # or
    #   tlm_with_units('target_name packet_name item_name')
    def tlm_with_units(*args)
      return $cmd_tlm_server.tlm_with_units(*args)
    end

    def tlm_variable(*args)
      return $cmd_tlm_server.tlm_variable(*args)
    end

    # Set a telemetry point to a given value. Note this will be over written in
    # a live system by incoming new telemetry.
    # Usage:
    #   set_tlm(target_name, packet_name, item_name, value)
    # or
    #   set_tlm("target_name packet_name item_name = value")
    def set_tlm(*args)
      return $cmd_tlm_server.set_tlm(*args)
    end

    # Set the raw value of a telemetry point to a given value. Note this will
    # be over written in a live system by incoming new telemetry.
    # Usage:
    #   set_tlm(target_name, packet_name, item_name, value)
    # or
    #   set_tlm("target_name packet_name item_name = value")
    def set_tlm_raw(*args)
      return $cmd_tlm_server.set_tlm_raw(*args)
    end

    # Injects a packet into the system as if it was received from an interface
    #
    # @param target_name[String] Target name of the packet
    # @param packet_name[String] Packet name of the packet
    # @param item_hash[Hash] Hash of item_name and value for each item you want to change from the current value table
    # @param value_type[Symbol/String] Type of the values in the item_hash (RAW or CONVERTED)
    # @param send_routers[Boolean] Whether or not to send to routers for the target's interface
    # @param send_packet_log_writers[Boolean] Whether or not to send to the packet log writers for the target's interface
    # @param create_new_logs[Boolean] Whether or not to create new log files before writing this packet to logs
    def inject_tlm(target_name, packet_name, item_hash = nil, value_type = :CONVERTED, send_routers = true, send_packet_log_writers = true, create_new_logs = false)
      return $cmd_tlm_server.inject_tlm(target_name, packet_name, item_hash, value_type, send_routers, send_packet_log_writers, create_new_logs)
    end

    # Gets all the values from the given packet returned in a two dimensional
    # array containing the item_name, value, and limits state.
    # Usage:
    #   values = get_tlm_packet(target_name, packet_name, <:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS>)
    def get_tlm_packet(target_name, packet_name, value_types = :CONVERTED)
      result = $cmd_tlm_server.get_tlm_packet(target_name, packet_name, value_types)
      result.each do |entry|
        entry[2] = entry[2].to_s.intern if entry[2]
      end
      result
    end

    # Gets all the values from the given packet returned in an
    # array consisting of an Array of item values, an array of item limits state
    # given as symbols such as :RED, :YELLOW, :STALE, an array of arrays including
    # the limits setting such as red low, yellow low, yellow high, red high and
    # optionally green low and high, and the overall limits state of the system.
    # Usage:
    #   values = get_tlm_values([[target_name, packet_name, item_name], ...], <:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS>)
    def get_tlm_values(items, value_types = :CONVERTED)
      result = $cmd_tlm_server.get_tlm_values(items, value_types)
      result[1].length.times do |index|
        result[1][index] = result[1][index].to_s.intern if result[1][index]
      end
      result[3] = result[3].to_s.intern
      result
    end

    # Gets the packets for a given target name. Returns an array of arrays
    # consisting of packet names and packet descriptions.
    def get_tlm_list(target_name)
      return $cmd_tlm_server.get_tlm_list(target_name)
    end

    # Gets all the telemetry mnemonics for a given target and packet. Returns an
    # array of arrays consisting of item names, item states, and item descriptions.
    def get_tlm_item_list(target_name, packet_name)
      return $cmd_tlm_server.get_tlm_item_list(target_name, packet_name)
    end

    # Gets the list of all defined targets.
    def get_target_list
      return $cmd_tlm_server.get_target_list
    end

    def get_tlm_details(items)
      $cmd_tlm_server.get_tlm_details(items)
    end

    # Returns the buffer from the telemetry packet.
    def get_tlm_buffer(target_name, packet_name)
      return $cmd_tlm_server.get_tlm_buffer(target_name, packet_name)
    end

    # Subscribe to one or more telemetry packets. The queue ID is returned for
    # use in get_packet_data and unsubscribe_packet_data.
    # Usage:
    #   id = subscribe_packet_data([[target_name,packet_name], ...], <queue_size>)
    def subscribe_packet_data(packets, queue_size = CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE)
      result = $cmd_tlm_server.subscribe_packet_data(packets, queue_size)
      result
    end

    # Unsubscribe to telemetry packets. Pass the queue ID which was returned by
    # the subscribe_packet_data method.
    # Usage:
    #   unsubscribe_packet_data(id)
    def unsubscribe_packet_data(id)
      result = $cmd_tlm_server.unsubscribe_packet_data(id)
      result
    end

    # DEPRECATED
    def get_packet_data(id, non_block = false)
      results = $cmd_tlm_server.get_packet_data(id, non_block)
      if Array === results and results[3] and results[4]
        results[3] = Time.at(results[3], results[4])
        results.delete_at(4)
      end
      results
    end

    # Get a packet which was previously subscribed to by
    # subscribe_packet_data. This method can block waiting for new packets or
    # not based on the second parameter. It returns a single Cosmos::Packet instance
    # and will return nil when no more packets are buffered (assuming non_block
    # is false).
    # Usage:
    #   get_packet(id, <true or false to block>)
    def get_packet(id, non_block = false)
      packet = nil
      buffer, target_name, packet_name, received_time, received_count = get_packet_data(id, non_block)
      if buffer
        packet = System.telemetry.packet(target_name, packet_name).clone
        packet.buffer = buffer
        packet.received_time = received_time
        packet.received_count = received_count
      end
      packet
    end

  end
end

