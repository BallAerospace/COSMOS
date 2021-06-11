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

  class TextLogMicroservice < Microservice

    def initialize(name)
      super(name)
      @config['options'].each do |option|
        case option[0].upcase
        when 'CYCLE_TIME' # Maximum time between log files
          @cycle_time = option[1].to_i
        when 'CYCLE_SIZE' # Maximum size of a log file
          @cycle_size = option[1].to_i
        else
          Logger.error("Unknown option passed to microservice #{@name}: #{option}")
        end
      end

      # These settings limit the log file to 10 minutes or 50MB of data, whichever comes first
      @cycle_time = 600 unless @cycle_time # 10 minutes
      @cycle_size = 50_000_000 unless @cycle_size # ~50 MB
    end

    def run
      tlws = setup_tlws
      while true
        break if @cancel_thread
        Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          break if @cancel_thread
          log_data(tlws, topic, msg_id, msg_hash, redis)
        end
      end
    end

    def setup_tlws
      tlws = {}
      @topics.each do |topic|
        topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
        scope = topic_split[0]
        log_name = topic_split[1]
        remote_log_directory = "#{scope}/textlogs/#{log_name}"
        tlws[topic] = TextLogWriter.new(remote_log_directory, true, @cycle_time, @cycle_size, redis_topic: topic)
      end
      return tlws
    end

    def log_data(tlws, topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      keys = msg_hash.keys
      keys.delete("time")
      entry = keys.reduce("") { |data, key| data + "#{key}: #{msg_hash[key]}\t" }
      tlws[topic].write(msg_hash["time"].to_i, entry, msg_id)
      @count += 1
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      @metric.add_sample(name: "log_duration_seconds", value: diff, labels: {})
    rescue => err
      @error = err
      Logger.error("#{@name} error: #{err.formatted}")
    end

  end
end

Cosmos::TextLogMicroservice.run if __FILE__ == $0
