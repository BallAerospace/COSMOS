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
  class IdentifyMicroservice < Microservice
    # The number of bytes to print when an UNKNOWN packet is received
    UNKNOWN_BYTES_TO_PRINT = 36

    def initialize(name)
      super(name)
      @cancel_thread = false
      @kafka_producer = @kafka_client.async_producer(delivery_interval: 1)
    end

    def run
      kafka_consumer_loop do |message|
        begin
          identify_packet(message)
          break if @cancel_thread
        rescue => err
          Logger.error("Identification error: #{err.formatted}")
        end
      end
    end

    def identify_packet(kafka_message)
      packet = Packet.new(nil, nil)
      #STDOUT.puts kafka_message.headers.inspect
      packet.target_name = kafka_message.headers["target_name"]
      packet.packet_name = kafka_message.headers["packet_name"]
      packet.stored = ConfigParser.handle_true_false(kafka_message.headers["stored"])
      packet.received_time = Time.parse(kafka_message.headers["time"])
      packet.buffer = kafka_message.value
      if packet.stored
        # Stored telemetry does not update the current value table
        identified_packet = System.telemetry.identify_and_define_packet(packet, @interface.target_names)
      else
        # Identify and update packet
        if packet.identified?
          begin
            # Preidentifed packet - place it into the current value table
            identified_packet = System.telemetry.update!(packet.target_name,
                                                         packet.packet_name,
                                                         packet.buffer)
          rescue RuntimeError
            # Packet identified but we don't know about it
            # Clear packet_name and target_name and try to identify
            Logger.warn "Received unknown identified telemetry: #{packet.target_name} #{packet.packet_name}"
            packet.target_name = nil
            packet.packet_name = nil
            identified_packet = System.telemetry.identify!(packet.buffer,
                                                           @interface.target_names)
          end
        else
          # Packet needs to be identified
          identified_packet = System.telemetry.identify!(packet.buffer,
                                                         @interface.target_names)
        end
      end

      if identified_packet
        identified_packet.received_time = packet.received_time
        identified_packet.stored = packet.stored
        identified_packet.extra = packet.extra
         packet = identified_packet
      else
        unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
        unknown_packet.received_time = packet.received_time
        unknown_packet.stored = packet.stored
        unknown_packet.extra = packet.extra
        packet = unknown_packet
        data_length = packet.length
        string = "#{@interface.name} - Unknown #{data_length} byte packet starting: "
        num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
        data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
        data_to_print.each_byte do |byte|
          string << sprintf("%02X", byte)
        end
        Logger.error string
      end

      target = System.targets[packet.target_name]
      target.tlm_cnt += 1 if target
      packet.received_count += 1

      # Write to Kafka
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name
      headers[:packet_name] = packet.packet_name
      headers[:received_count] = packet.received_count
      @kafka_producer.produce(packet.buffer, topic: "PACKET__#{packet.target_name}__#{packet.packet_name}", :headers => headers)
    end
  end
end

Cosmos::IdentifyMicroservice.run if __FILE__ == $0
