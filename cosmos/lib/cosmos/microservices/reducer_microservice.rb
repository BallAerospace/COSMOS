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
require 'cosmos/packets/json_packet'
require 'cosmos/utilities/s3_file_cache'
require 'cosmos/models/reducer_model'
require 'rufus-scheduler'

module Cosmos
  class ReducerMicroservice < Microservice
    MINUTE_METRIC = 'reducer_minute_duration'
    HOUR_METRIC = 'reducer_hour_duration'
    DAY_METRIC = 'reducer_day_duration'

    # How long to wait for any currently running jobs to complete before killing them
    SHUTDOWN_DELAY_SECS = 1

    def initialize(name)
      super(name, is_plugin: false)
      @packet_logs = {}
    end

    def run
      # Note it takes several seconds to create the scheduler
      @scheduler = Rufus::Scheduler.new
      @scheduler.cron '* * * * *', first: :now do
        reduce_minute
      end
      @scheduler.cron '0 * * * *', first: :now do
        reduce_hour
      end
      @scheduler.cron '0 0 * * *', first: :now do
        reduce_day
      end

      # Let the current thread join the scheduler thread and
      # block until shutdown is called
      @scheduler.join
    end

    def shutdown
      @packet_logs.each { |_, log| log.shutdown }
      @scheduler.shutdown(wait: SHUTDOWN_DELAY_SECS) if @scheduler
      super()
    end

    def metric(name)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      @metric.add_sample(
        name: name,
        value: elapsed,
        labels: {
          'target' => @target,
        },
      )
    end

    def reduce_minute
      metric(MINUTE_METRIC) do
        ReducerModel.all_decom(scope: @scope).each do |file|
          puts "file:#{file}"
          if process_file(file, "minute", 60, 3600)
            ReducerModel.rm_decom(filename: file, scope: @scope)
          end
        end
      end
    end

    def reduce_hour
      # metric(HOUR_METRIC) do
      #   ReducerModel.all_minute(scope: @scope).each do |file|
      #     process_file(file)
      #   end
      # end
    end

    def reduce_day
      # metric(DAY_METRIC) do
      #   ReducerModel.all_hour(scope: @scope).each do |filename|
      #     process_file(filename)
      #   end
      # end
    end

    def process_file(filename, type, entry_seconds, file_seconds)
      file = S3File.new(filename)
      file.retrieve

      # Determine if we already have a PacketLogWriter created
      start_time, end_time, scope, target_name, packet_name, _ = filename.split('__')
      plw = @packet_logs["#{scope}__#{target_name}__#{packet_name}__#{type}"]
      unless plw
        # Create a new PacketLogWriter for this reduced data
        remote_log_directory = "#{scope}/reduced_logs/tlm/#{target_name}/#{packet_name}"
        rt_label = "#{scope}__#{target_name}__#{packet_name}__reduced__#{type}"
        puts "log_dir:#{remote_log_directory} rt_label:#{rt_label}"
        plw = PacketLogWriter.new(remote_log_directory, rt_label)
        @packet_logs["#{scope}__#{target_name}__#{packet_name}__#{type}"] = plw
      end

      reduced = {}
      entry_time = nil
      current_time = nil
      previous_time = nil
      plr = Cosmos::PacketLogReader.new()
      plr.each(file.local_path) do |packet|
        data = packet.read_all(:CONVERTED)
        # Ignore anything except numbers, this automatically ignores limits, formatted and units values
        data.select! { |key, value| value.is_a?(Numeric) }
        previous_time = current_time
        current_time = data['PACKET_TIMESECONDS']
        entry_time ||= current_time
        puts "current:#{current_time} previous:#{previous_time}"

        # Determine if we've rolled over a entry boundary
        # We have to use current mod less than previous mod because
        # we don't know the data rates. We also have to check for current - previous > mod
        # in case the data rate is so slow we don't have multiple samples
        if previous_time && ((current_time % entry_seconds < previous_time % entry_seconds) ||
          (current_time - previous_time >= entry_seconds))
          # We've collected all the values so calculate the AVG and STDDEV
          if type == "minute"
            data.keys.each do |key|
              reduced["#{key}__SAMPLES"] = reduced["#{key}__VALS"].length
              reduced["#{key}__AVG"], reduced["#{key}__STDDEV"] =
                Math.stddev_population(reduced["#{key}__VALS"])
              # Remove the raw values as they're only used for AVG / STDDEV calculation
              data.delete("#{key}__VALS")
            end
          end
          plw.write(:JSON_PACKET, :TLM, target_name, packet_name, entry_time * Time::NSEC_PER_SECOND, false, JSON.generate(reduced.as_json))

          # Check to see if we should start a new log file
          if (plw.last_time - plw.first_time) >= file_seconds
            puts "\n\n!!!!!!!!!!!!!!!!NEW FILE!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
            puts "old filename:#{plw.filename}"
            plw.start_new_file # Automatically closes the current file
            puts "new filename:#{plw.filename}"
          end

          # Reset all our sample variables
          entry_time = current_time
          reduced = {}
        end

        data.each do |key, value|
          reduced["#{key}__VALS"] ||= []
          reduced["#{key}__VALS"] << value
          reduced["#{key}__MIN"] ||= value
          reduced["#{key}__MIN"] = value if value < reduced["#{key}__MIN"]
          reduced["#{key}__MAX"] ||= value
          reduced["#{key}__MAX"] = value if value > reduced["#{key}__MAX"]
        #   else
        #     total_samples = num_samples * values.length
        #     reduced[key] = values.min if key.include?('__MIN')
        #     reduced[key] = values.max if key.include?('__MAX')

        #     # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
        #     if key.include?('__AVG')
        #       reduced[key] =
        #         values.sum { |v| v * num_samples } / total_samples.to_f
        #     end
        end

        # # Do the STDDEV calc last so we can use the previously calculated AVG
        # if type != "minute"
        #   data
        #     .keys
        #     .select { |k| k.include?('__STDDEV') }
        #     .each do |key|
        #       values = data[key]

        #       # puts "key:#{key} vals:#{values} total:#{total_samples}" if key.include?('COLLECTS')
        #       # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
        #       avg_key = "#{key[0...-8]}__AVG"
        #       avg_vals = data[avg_key]

        #       # puts "avg key:#{avg_key} vals:#{avg_vals} reduced:#{reduced[avg_key]}" if key.include?('COLLECTS')
        #       s2 = 0
        #       values.each_with_index do |val, i|
        #         # puts "i:#{i} std:#{val} avg:#{avg_vals[i]}" if key.include?('COLLECTS')
        #         s2 += (num_samples * (avg_vals[i]**2 + val**2))
        #       end

        #       # puts "s2:#{s2} samples:#{num_samples} total:#{num_samples * values.length}" if key.include?('COLLECTS')
        #       # Note: For very large numbers with very small deviations this sqrt can fail.  If so then just set the stddev to 0.
        #       begin
        #         reduced[key] = Math.sqrt(s2 / total_samples - reduced[avg_key]**2)
        #       rescue Exception
        #         reduced[key] = 0.0
        #       end
        #     end
        # end
      end
      file.delete
      true
    end


      # target_name = messages[0][1]['target_name']
      # packet_name = messages[0][1]['packet_name']
      # msg_hash = {
      #   time: idi(messages[-1][0]) * 1_000_000, # Convert milliseconds to nanoseconds
      #   target_name: target_name,
      #   packet_name: packet_name,
      #   num_samples: total_samples,
      #   json_data: JSON.generate(reduced.as_json),
      # }
      # id = @test ? "#{idi(messages[-1][0])}-0" : nil
      # Store.write_topic(
      #   "#{scope}__#{topic_key}__{#{target_name}}__#{packet_name}",
      #   msg_hash,
      #   id,
      # )

    private

    # Convert String of nanoseconds to Integer milliseconds
    def ns_ms(nanoseconds)
      nanoseconds.to_i / 1_000_000
    end

    # Return the ID integer (idi) from a Redis Stream ID
    def idi(id)
      # See https://redis.io/topics/streams-intro for more info
      # Stream IDs are formatted as timestamp dash sequence, e.g. 1519073278252-0
      id.split('-')[0].to_i
    end
  end
end

Cosmos::ReducerMicroservice.run if __FILE__ == $0
