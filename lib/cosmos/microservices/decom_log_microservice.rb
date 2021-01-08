# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'
require 'cosmos/topics/topic'

module Cosmos
  class DecomLogMicroservice < Microservice
    def run
      plws = {}
      @topics.each do |topic|
        topic_split = topic.split("__")
        scope = topic_split[0]
        target_name = topic_split[2]
        packet_name = topic_split[3]
        remote_log_directory = "#{scope}/decomlogs/tlm/#{target_name}/#{packet_name}"
        label = "#{scope}__#{target_name}__#{packet_name}__decom"
        plws[topic] = PacketLogWriter.new(remote_log_directory, label, true, nil, 10000000, 0, 0)
      end
      while true
        break if @cancel_thread
        Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          begin
            break if @cancel_thread
            topic_split = topic.split("__")
            target_name = topic_split[2]
            packet_name = topic_split[3]

            plws[topic].write(:JSON_PACKET, :TLM, target_name, packet_name, msg_hash["time"].to_i, ConfigParser.handle_true_false(msg_hash["stored"]), msg_hash["json_data"], nil)
            @count += 1
          rescue => err
            @error = err
            Logger.error("DecomLog error: #{err.formatted}")
          end
        end
      end
    end
  end
end

Cosmos::DecomLogMicroservice.run if __FILE__ == $0
