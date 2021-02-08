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

require 'cosmos/microservices/microservice'
require 'cosmos/topics/telemetry_decom_topic'
require 'cosmos/topics/limits_event_topic'

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
          Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
            break if @cancel_thread
            decom_packet(topic, msg_id, msg_hash, redis)
            @count += 1
          end
        rescue => err
          @error = err
          Logger.error("Decom error: #{err.formatted}")
        end
      end
    end

    decom_packet_metric_name = "decom_packet_duration_seconds"

    def decom_packet(topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      target_name = msg_hash["target_name"]
      packet_name = msg_hash["packet_name"]

      packet = System.telemetry.packet(target_name, packet_name)
      packet.stored = ConfigParser.handle_true_false(msg_hash["stored"])
      packet.received_time = Time.from_nsec_from_epoch(msg_hash["time"].to_i)
      packet.received_count = msg_hash["received_count"].to_i
      packet.buffer = msg_hash["buffer"]
      packet.check_limits

      TelemetryDecomTopic.write_packet(packet, scope: @scope)
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = {"packet" => packet_name, "target" => target_name}
      @metric.add_sample(name: decom_packet_metric_name, value: diff, labels: metric_labels)
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
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      packet_time = packet.packet_time
      message = "#{packet.target_name} #{packet.packet_name} #{item.name} = #{value} is #{item.limits.state}"
      message << " (#{packet.packet_time.sys.formatted})" if packet_time

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
      LimitsEventTopic.write(type: 'LIMITS_CHANGE', target_name: packet.target_name, packet_name: packet.packet_name,
        item_name: item.name, old_limits_state: old_limits_state, new_limits_state: item.limits.state,
        time_nsec: packet_time ? packet_time.to_nsec_from_epoch : Time.now.to_nsec_from_epoch, message: message, scope: @scope)

      if item.limits.response
        begin
          item.limits.response.call(packet, item, old_limits_state)
        rescue Exception => err
          @error = err
          Logger.error "#{packet.target_name} #{packet.packet_name} #{item.name} Limits Response Exception!"
          Logger.error "Called with old_state = #{old_limits_state}, new_state = #{item.limits.state}"
          Logger.error err.formatted
        end
      end

      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_name = "#{self.__method__.to_s}_duration_seconds".downcase
      labels = {"packet" => packet.packet_name, "target" => packet.target_name}
      @metric.add_sample(metric_name, diff, labels)
    end

  end

end

Cosmos::DecomMicroservice.run if __FILE__ == $0
