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
  class CvtMicroservice < Microservice
    def run
      while true
        break if @cancel_thread
        Store.instance.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          begin
            cvt_data(topic, msg_id, msg_hash, redis)
            break if @cancel_thread
          rescue => err
            Logger.error("Cvt error: #{err.formatted}")
          end
        end
      end
    end

    def cvt_data(topic, msg_id, msg_hash, redis)
      target_name = msg_hash["target_name"]
      packet_name = msg_hash["packet_name"]
      json_hash = JSON.parse(msg_hash['json_data'])
      # JSON encode each value to keep data types
      updated_json_hash = {}
      json_hash.each do |key, value|
        updated_json_hash[key] = JSON.generate(value.as_json)
      end
      @redis.mapped_hmset("tlm__#{target_name}__#{packet_name}", updated_json_hash)
    end
  end
end

Cosmos::CvtMicroservice.run if __FILE__ == $0
