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

  class LogMicroservice < Microservice

    def initialize(name)
      super(name)
      @config['options'].each do |option|
        case option[0].upcase
        when 'RAW_OR_DECOM'
          @raw_or_decom = option[1].intern
        when 'CMD_OR_TLM'
          @cmd_or_tlm = option[1].intern
        when 'CYCLE_TIME' # Maximum time between log files
          @cycle_time = option[1].to_i
        when 'CYCLE_SIZE' # Maximum size of a log file
          @cycle_size = option[1].to_i
        else
          Logger.error("Unknown option passed to microservice #{@name}: #{option}")
        end
      end

      raise "Microservice #{@name} not fully configured" unless @raw_or_decom and @cmd_or_tlm

      # These settings limit the log file to 10 minutes or 50MB of data, whichever comes first
      @cycle_time = 600 unless @cycle_time # 10 minutes
      @cycle_size = 50_000_000 unless @cycle_size # ~50 MB
    end

    def run
      plws = setup_plws
      while true
        break if @cancel_thread
        Topic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
          break if @cancel_thread
          log_data(plws, topic, msg_id, msg_hash, redis)
        end
      end
    end

    def setup_plws
      plws = {}
      @topics.each do |topic|
        topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
        scope = topic_split[0]
        target_name = topic_split[2]
        packet_name = topic_split[3]
        type = @raw_or_decom.to_s.downcase
        remote_log_directory = "#{scope}/#{type}logs/#{@cmd_or_tlm.to_s.downcase}/#{target_name}/#{packet_name}"
        rt_label = "#{scope}__#{target_name}__#{packet_name}__rt__#{type}"
        stored_label = "#{scope}__#{target_name}__#{packet_name}__stored__#{type}"
        plws[topic] = {
          :RT => PacketLogWriter.new(remote_log_directory, rt_label, true, @cycle_time, @cycle_size, redis_topic: topic),
          :STORED => PacketLogWriter.new(remote_log_directory, stored_label, true, @cycle_time, @cycle_size, redis_topic: topic)
        }
      end
      return plws
    end

    def log_data(plws, topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
      target_name = topic_split[2]
      packet_name = topic_split[3]
      rt_or_stored = ConfigParser.handle_true_false(msg_hash["stored"]) ? :STORED : :RT
      packet_type = nil
      data_key = nil
      if @raw_or_decom == :RAW
        packet_type = :RAW_PACKET
        data_key = "buffer"
      else # :DECOM
        packet_type = :JSON_PACKET
        data_key = "json_data"
      end
      plws[topic][rt_or_stored].write(packet_type, @cmd_or_tlm, target_name, packet_name, msg_hash["time"].to_i, rt_or_stored == :STORED, msg_hash[data_key], nil, msg_id)
      @count += 1
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { "packet" => packet_name, "target" => target_name, "raw_or_decom" => @raw_or_decom.to_s, "cmd_or_tlm" => @cmd_or_tlm.to_s }
      @metric.add_sample(name: "log_duration_seconds", value: diff, labels: metric_labels)
    rescue => err
      @error = err
      Logger.error("#{@name} error: #{err.formatted}")
    end

  end
end

Cosmos::LogMicroservice.run if __FILE__ == $0
