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
      packet.received_time = Time.parse(msg_hash["time"])
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
        json_hash["time"] = packet.received_time.to_i
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
        limits_state = item.limits.state
        json_hash[item.name + "__L"] = limits_state if limits_state
      end

      # Write to stream
      msg_hash.delete("buffer")
      msg_hash['json_data'] = JSON.generate(json_hash.as_json)
      Store.instance.write_topic("DECOM__#{target_name}__#{packet_name}", msg_hash)
    end
  end
end

Cosmos::DecomMicroservice.run if __FILE__ == $0
