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
        when 'LOG_TYPE'
          @log_type = option[1].intern
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

      raise "Microservice #{@name} not fully configured" unless @log_type and @cmd_or_tlm

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
        type = @log_type.to_s.downcase
        remote_log_directory = "#{scope}/#{type}_logs/#{@cmd_or_tlm.to_s.downcase}/#{target_name}/#{packet_name}"
        rt_label = "#{scope}__#{target_name}__#{packet_name}__rt__#{type}"
        stored_label = "#{scope}__#{target_name}__#{packet_name}__stored__#{type}"
        min_label = "#{scope}__#{target_name}__#{packet_name}__min__#{type}"
        hour_label = "#{scope}__#{target_name}__#{packet_name}__hour__#{type}"
        day_label = "#{scope}__#{target_name}__#{packet_name}__day__#{type}"
        plws[topic] = {
          :RT => PacketLogWriter.new(remote_log_directory, rt_label, true, @cycle_time, @cycle_size, redis_topic: topic),
          :STORED => PacketLogWriter.new(remote_log_directory, stored_label, true, @cycle_time, @cycle_size, redis_topic: topic)
          :MIN => PacketLogWriter.new(remote_log_directory, min_label, true, @cycle_time, @cycle_size, redis_topic: topic)
          :HOUR => PacketLogWriter.new(remote_log_directory, hour_label, true, @cycle_time, @cycle_size, redis_topic: topic)
          :DAY => PacketLogWriter.new(remote_log_directory, day_label, true, @cycle_time, @cycle_size, redis_topic: topic)
        }
      end
      return plws
    end

    def log_data(plws, topic, msg_id, msg_hash, redis)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      topic_split = topic.gsub(/{|}/, '').split("__") # Remove the redis hashtag curly braces
      target_name = topic_split[2]
      packet_name = topic_split[3]
      log_key = ConfigParser.handle_true_false(msg_hash["stored"]) ? :STORED : :RT
      packet_type = nil
      data_key = nil
      case @log_type
      when :RAW
        packet_type = :RAW_PACKET
        data_key = "buffer"
      when :DECOM
        packet_type = :JSON_PACKET
        data_key = "json_data"
      when :REDUCED
        packet_type = :JSON_PACKET
        data_key = "json_data"
        # Name is SCOPE__<MIN|HOUR|DAY>_LOG__TARGET
        log_key = @name.split('__')[1].split('_')[0].intern
      end
      # NOTE: The PacketLogWriter class writes packets until the file is closed due to being
      # a certain size or after a certain time period. The write method handles all this logic.
      # It also automatically trims the Redis streams after a file closes.
      # See LogWriter::close_file and Store::trim_topic for more information
      plws[topic][log_key].write(packet_type, @cmd_or_tlm, target_name, packet_name, msg_hash["time"].to_i, log_key == :STORED, msg_hash[data_key], nil, msg_id)
      @count += 1
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { "packet" => packet_name, "target" => target_name, "log_type" => @log_type.to_s, "cmd_or_tlm" => @cmd_or_tlm.to_s }
      @metric.add_sample(name: "log_duration_seconds", value: diff, labels: metric_labels)
    rescue => err
      @error = err
      Logger.error("#{@name} error: #{err.formatted}")
    end
  end
end

Cosmos::LogMicroservice.run if __FILE__ == $0
