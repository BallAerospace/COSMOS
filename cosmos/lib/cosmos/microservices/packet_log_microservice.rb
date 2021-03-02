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
require 'cosmos/topics/topic'

module Cosmos

  class PacketLogMicroservice < Microservice

    METRIC_NAME = "packet_log_duration_seconds"

    def run
      plws = setup_plws
      while true
        break if @cancel_thread
        Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          break if @cancel_thread
          packet_log_data(plws, topic, msg_id, msg_hash, redis)
        end
      end
    end

    def setup_plws
      plws = {}
      @topics.each do |topic|
        topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
        target_name = topic_split[2]
        packet_name = topic_split[3]
        remote_log_directory = "#{@scope}/rawlogs/tlm/#{target_name}/#{packet_name}"
        rt_label = "#{@scope}__#{target_name}__#{packet_name}__rt__raw"
        stored_label = "#{@scope}__#{target_name}__#{packet_name}__stored__raw"
        plws[topic] = {
          :RT => PacketLogWriter.new(remote_log_directory, rt_label, true, nil, 1000000, 0, 0),
          :STORED => PacketLogWriter.new(remote_log_directory, stored_label, true, nil, 1000000, 0, 0)
        }
      end
      return plws
    end

    def packet_log_data(plws, topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
      target_name = topic_split[2]
      packet_name = topic_split[3]
      rt_or_stored = ConfigParser.handle_true_false(msg_hash["stored"]) ? :STORED : :RT
      plws[topic][rt_or_stored].write(:RAW_PACKET, :TLM, target_name, packet_name, msg_hash["time"].to_i, rt_or_stored == :STORED, msg_hash["buffer"], nil, msg_id)
      @count += 1
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { "packet" => packet_name, "target" => target_name }
      @metric.add_sample(name: METRIC_NAME, value: diff, labels: metric_labels)
    rescue => err
      @error = err
      Logger.error("PacketLog error: #{err.formatted}")
    end

  end
end

Cosmos::PacketLogMicroservice.run if __FILE__ == $0
