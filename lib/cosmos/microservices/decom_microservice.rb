# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'

module Cosmos
  class DecomMicroservice < Microservice

    def initialize(*args)
      super(*args)
      System.telemetry.limits_change_callback = method(:limits_change_callback)
    end

    def run
      while true
        break if @cancel_thread
        begin
          Store.instance.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
            break if @cancel_thread
            decom_packet(topic, msg_id, msg_hash, redis)
          end
        rescue => err
          Logger.error("Decom error: #{err.formatted}")
        end
      end
    end

    def decom_packet(topic, msg_id, msg_hash, redis)
      # TODO: Could also pull this by splitting the topic name?
      target_name = msg_hash["target_name"]
      packet_name = msg_hash["packet_name"]

      packet = System.telemetry.packet(target_name, packet_name)
      packet.stored = ConfigParser.handle_true_false(msg_hash["stored"])
      packet.received_time = Time.from_nsec_from_epoch(msg_hash["time"].to_i)
      packet.received_count = msg_hash["received_count"].to_i
      packet.buffer = msg_hash["buffer"]
      packet.check_limits

      # Need to build a JSON hash of the decommutated data
      # Support "downward typing"
      # everything base name is RAW (including DERIVED)
      # Request for WITH_UNITS, etc will look down until it finds something
      # If nothing - item does not exist - nil
      # __ as seperators ITEM1, ITEM1__C, ITEM1__F, ITEM1__U

      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
        limits_state = item.limits.state
        json_hash[item.name + "__L"] = limits_state if limits_state
      end

      # Write to stream
      msg_hash.delete("buffer")
      # TODO: msg_hash['time'] = json_hash['PACKET_TIME_NSEC']
      msg_hash['json_data'] = JSON.generate(json_hash.as_json)
      Store.instance.write_topic("#{@scope}__DECOM__#{target_name}__#{packet_name}", msg_hash)
    end

    # Called when an item in any packet changes limits states.
    #
    # @param packet [Packet] Packet which has had an item change limits state
    # @param item [PacketItem] The item which has changed limits state
    # @param old_limits_state [Symbol] The previous state of the item. See
    #   {PacketItemLimits#state}
    # @param value [Object] The current value of the item
    # @param log_change [Boolean] Whether to log this limits change event
    def limits_change_callback(packet, item, old_limits_state, value, log_change)
      packet_time = packet.packet_time
      tgt_pkt_item_str = "#{packet.target_name} #{packet.packet_name} #{item.name} = #{value} is"
      pkt_time_str = ""
      pkt_time_str << " (#{packet.packet_time.sys.formatted})" if packet_time
      message = "#{tgt_pkt_item_str} #{item.limits.state}#{pkt_time_str}"

      if log_change
        case item.limits.state
        when :BLUE, :GREEN, :GREEN_LOW, :GREEN_HIGH
          Logger.info message
        when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
          Logger.warn message
        when :RED, :RED_LOW, :RED_HIGH
          Logger.error message
        else
          Logger.error "#{tgt_pkt_item_str} UNKNOWN#{pkt_time_str}"
        end
      end

      # The cosmos_limits_events topic can be listened to for all limits events, it is a continuous stream
      Store.instance.write_topic("#{@scope}__cosmos_limits_events",
        {type: 'LIMITS_CHANGE', target_name: packet.target_name, packet_name: packet.packet_name,
          item_name: item.name, old_limits_state: old_limits_state, new_limits_state: item.limits.state,
          time_nsec: packet_time ? packet_time.to_nsec_from_epoch : Time.now.to_nsec_from_epoch, message: message})
      # The current_limits hash keeps only the current limits state of items
      # It is used by the API to determine the overall limits state
      # TODO: How do we maintain / clean this hash?
      Store.instance.hset("#{@scope}__current_limits",
        "#{packet.target_name}__#{packet.packet_name}__#{item.name}",
        item.limits.state)

      if item.limits.response
        begin
          item.limits.response.call(packet, item, old_limits_state)
        rescue Exception => err
          Logger.error "#{packet.target_name} #{packet.packet_name} #{item.name} Limits Response Exception!"
          Logger.error "Called with old_state = #{old_limits_state}, new_state = #{item.limits.state}"
          Logger.error err.formatted
        end
      end
    end
  end
end

Cosmos::DecomMicroservice.run if __FILE__ == $0
