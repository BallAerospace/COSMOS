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

    def setup_plws()
      plws = {}
      @topics.each do |topic|
        topic_split = topic.split("__")
        target_name = topic_split[2]
        packet_name = topic_split[3]
        remote_log_directory = "#{@scope}/rawlogs/tlm/#{target_name}/#{packet_name}"
        label = "#{@scope}__#{target_name}__#{packet_name}__raw"
        plws[topic] = PacketLogWriter.new(remote_log_directory, label, true, nil, 1000000, 0, 0)
      end
      return plws
    end

    packet_log_metric_name = "packet_log_duration_seconds"

    def packet_log_data(plws, topic, msg_id, msg_hash, redis)
      begin
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        topic_split = topic.split("__")
        target_name = topic_split[2]
        packet_name = topic_split[3]
        plws[topic].write(:RAW_PACKET, :TLM, target_name, packet_name, msg_hash["time"].to_i, ConfigParser.handle_true_false(msg_hash["stored"]), msg_hash["buffer"], nil)
        @count += 1
        diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
        metric_labels = {"packet" => packet_name, "target" => target_name}
        @metric.add_sample(name: packet_log_metric_name, value: diff, labels: metric_labels)
      rescue => err
        @error = err
        Logger.error("PacketLog error: #{err.formatted}")
      end
    end

  end
end

Cosmos::PacketLogMicroservice.run if __FILE__ == $0
