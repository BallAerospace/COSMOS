# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/microservices/microservice'
require 'openc3/topics/telemetry_decom_topic'
require 'openc3/topics/limits_event_topic'
require 'openc3/topics/notifications_topic'
require 'openc3/models/notification_model'

module OpenC3
  class DecomMicroservice < Microservice
    DECOM_METRIC_NAME = "decom_packet_duration_seconds"
    LIMIT_METRIC_NAME = "limits_change_callback_duration_seconds"
    NS_PER_MSEC = 1000000

    def initialize(*args)
      super(*args)
      Topic.update_topic_offsets(@topics)
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
        rescue => e
          @error = e
          Logger.error("Decom error: #{e.formatted}")
        end
      end
    end

    def decom_packet(topic, _msg_id, msg_hash, _redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      target_name = msg_hash["target_name"]
      packet_name = msg_hash["packet_name"]

      current_limits_set = LimitsEventTopic.current_set(scope: @scope)

      packet = System.telemetry.packet(target_name, packet_name)
      packet.stored = ConfigParser.handle_true_false(msg_hash["stored"])
      packet.received_time = Time.from_nsec_from_epoch(msg_hash["time"].to_i)
      packet.received_count = msg_hash["received_count"].to_i
      packet.buffer = msg_hash["buffer"]
      packet.check_limits(current_limits_set.intern) # Process all the limits and call the limits_change_callback (as necessary)

      TelemetryDecomTopic.write_packet(packet, scope: @scope)
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { "packet" => packet_name, "target" => target_name }
      @metric.add_sample(name: DECOM_METRIC_NAME, value: diff, labels: metric_labels)
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

      time_nsec = packet_time ? packet_time.to_nsec_from_epoch : Time.now.to_nsec_from_epoch
      if log_change
        case item.limits.state
        when :BLUE, :GREEN, :GREEN_LOW, :GREEN_HIGH
          Logger.info message
        when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
          Logger.warn message
        when :RED, :RED_LOW, :RED_HIGH
          # TODO: Is this necessary? The LimitsEventTopic is what communicates with LimitsMonitor
          notification = NotificationModel.new(
            time: time_nsec,
            severity: "critical",
            url: "/tools/limitsmonitor",
            title: "#{packet.target_name} #{packet.packet_name} #{item.name} out of limits",
            body: "Item went into #{item.limits.state} limit status."
          )
          NotificationsTopic.write_notification(notification.as_json(:allow_nan => true), scope: @scope)
          Logger.error message
        end
      end

      # The openc3_limits_events topic can be listened to for all limits events, it is a continuous stream
      event = { type: :LIMITS_CHANGE, target_name: packet.target_name, packet_name: packet.packet_name,
                item_name: item.name, old_limits_state: old_limits_state, new_limits_state: item.limits.state,
                time_nsec: time_nsec, message: message }
      LimitsEventTopic.write(event, scope: @scope)

      if item.limits.response
        begin
          item.limits.response.call(packet, item, old_limits_state)
        rescue Exception => e
          @error = e
          Logger.error "#{packet.target_name} #{packet.packet_name} #{item.name} Limits Response Exception!"
          Logger.error "Called with old_state = #{old_limits_state}, new_state = #{item.limits.state}"
          Logger.error e.formatted
        end
      end

      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      labels = { "packet" => packet.packet_name, "target" => packet.target_name }
      @metric.add_sample(name: LIMIT_METRIC_NAME, value: diff, labels: labels)
    end
  end
end

OpenC3::DecomMicroservice.run if __FILE__ == $0
