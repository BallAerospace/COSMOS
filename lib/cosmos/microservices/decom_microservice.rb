# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'
require 'cosmos/io/json_rpc'

module Cosmos
  class DecomMicroservice < Microservice
    def initialize(name)
      super(name)
      @kafka_producer = @kafka_client.async_producer(delivery_interval: 1)
    end

    def run
      kafka_consumer_loop do |message|
        begin
          decom_packet(message)
          break if @cancel_thread
        rescue => err
          Logger.error("Decom error: #{err.formatted}")
        end
      end
    end

    def decom_packet(kafka_message)
      # TODO: Could also pull this by splitting the topic name?
      target_name = kafka_message.headers["target_name"]
      packet_name = kafka_message.headers["packet_name"]

      packet = System.telemetry.packet(target_name, packet_name)
      packet.stored = ConfigParser.handle_true_false(kafka_message.headers["stored"])
      packet.received_time = Time.parse(kafka_message.headers["time"])
      packet.received_count = kafka_message.headers["received_count"].to_i
      packet.buffer = kafka_message.value
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

      # Write to Kafka
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name
      headers[:packet_name] = packet.packet_name
      headers[:received_count] = packet.received_count
      @kafka_producer.produce(JSON.generate(json_hash.as_json), topic: "DECOM__#{target_name}__#{packet_name}", :headers => headers)
      @kafka_producer.deliver_messages
    end
  end
end

Cosmos::DecomMicroservice.run if __FILE__ == $0
