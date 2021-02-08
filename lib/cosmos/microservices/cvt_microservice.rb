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
require 'cosmos/models/cvt_model'
require 'cosmos/topics/topic'

module Cosmos

  class CvtMicroservice < Microservice

    def run
      while true
        break if @cancel_thread
        Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          begin
            cvt_data(topic, msg_id, msg_hash, redis)
            @count += 1
            break if @cancel_thread
          rescue => err
            @error = err
            Logger.error("Cvt error: #{err.formatted}")
          end
        end
      end
    end

    cvt_metric_name = "cvt_data_duration_seconds"

    def cvt_data(topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      target_name = msg_hash["target_name"]
      packet_name = msg_hash["packet_name"]
      json_hash = JSON.parse(msg_hash['json_data'])
      # JSON encode each value to keep data types
      updated_json_hash = {}
      json_hash.each do |key, value|
        updated_json_hash[key] = JSON.generate(value.as_json)
      end
      CvtModel.set(updated_json_hash, target_name: target_name, packet_name: packet_name, scope: @scope)
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = {"packet" => packet_name, "target" => target_name}
      @metric.add_sample(name: cvt_metric_name, value: diff, labels: metric_labels)
    end

  end
end

Cosmos::CvtMicroservice.run if __FILE__ == $0
