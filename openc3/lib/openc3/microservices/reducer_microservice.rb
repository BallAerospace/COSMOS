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
require 'openc3/topics/topic'
require 'openc3/packets/json_packet'
require 'openc3/utilities/s3_file_cache'
require 'openc3/models/reducer_model'
require 'rufus-scheduler'

module OpenC3
  class ReducerMicroservice < Microservice
    MINUTE_METRIC = 'reducer_minute_duration'
    HOUR_METRIC = 'reducer_hour_duration'
    DAY_METRIC = 'reducer_day_duration'

    # How long to wait for any currently running jobs to complete before killing them
    SHUTDOWN_DELAY_SECS = 5
    MINUTE_ENTRY_SECS = 60
    MINUTE_FILE_SECS = 3600
    HOUR_ENTRY_SECS = 3600
    HOUR_FILE_SECS = 3600 * 24
    DAY_ENTRY_SECS = 3600 * 24
    DAY_FILE_SECS = 3600 * 24 * 30

    # @param name [String] Microservice name formatted as <SCOPE>__REDUCER__<TARGET>
    #   where <SCOPE> and <TARGET> are variables representing the scope name and target name
    def initialize(name)
      super(name, is_plugin: false)
      @target_name = name.split('__')[-1]
      @packet_logs = {}
    end

    def run
      # Note it takes several seconds to create the scheduler
      @scheduler = Rufus::Scheduler.new
      # Run every minute
      @scheduler.cron '* * * * *', first: :now do
        reduce_minute
      end
      # Run every 15 minutes
      @scheduler.cron '*/15 * * * *', first: :now do
        reduce_hour
      end
      # Run hourly at minute 5 to allow the hour reducer to finish
      @scheduler.cron '5 * * * *', first: :now do
        reduce_day
      end

      # Let the current thread join the scheduler thread and
      # block until shutdown is called
      @scheduler.join
    end

    def shutdown
      @scheduler.shutdown(wait: SHUTDOWN_DELAY_SECS) if @scheduler

      # Make sure all the existing logs are properly closed down
      @packet_logs.each do |name, log|
        log.shutdown
      end
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
          'target' => @target_name,
        },
      )
    end

    def reduce_minute
      metric(MINUTE_METRIC) do
        ReducerModel
          .all_files(type: :DECOM, target: @target_name, scope: @scope)
          .each do |file|
            process_file(file, 'minute', MINUTE_ENTRY_SECS, MINUTE_FILE_SECS)
            ReducerModel.rm_file(file)
          end
      end
    end

    def reduce_hour
      metric(HOUR_METRIC) do
        ReducerModel
          .all_files(type: :MINUTE, target: @target_name, scope: @scope)
          .each do |file|
            process_file(file, 'hour', HOUR_ENTRY_SECS, HOUR_FILE_SECS)
            ReducerModel.rm_file(file)
          end
      end
    end

    def reduce_day
      metric(DAY_METRIC) do
        ReducerModel
          .all_files(type: :HOUR, target: @target_name, scope: @scope)
          .each do |file|
            process_file(file, 'day', DAY_ENTRY_SECS, DAY_FILE_SECS)
            ReducerModel.rm_file(file)
          end
      end
    end

    def process_file(filename, type, entry_seconds, file_seconds)
      file = S3File.new(filename)
      file.retrieve

      # Determine if we already have a PacketLogWriter created
      start_time, end_time, scope, target_name, packet_name, _ =
        filename.split('__')
      if @target_name != target_name
        raise "Target name in file #{filename} does not match microservice target name #{@target_name}"
      end
      plw = @packet_logs["#{scope}__#{target_name}__#{packet_name}__#{type}"]
      unless plw
        # Create a new PacketLogWriter for this reduced data
        # e.g. DEFAULT/reduced_minute_logs/tlm/INST/HEALTH_STATUS/20220101/
        # 20220101204857274290500__20220101205857276524900__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin
        remote_log_directory = "#{scope}/reduced_#{type}_logs/tlm/#{target_name}/#{packet_name}"
        rt_label = "#{scope}__#{target_name}__#{packet_name}__reduced__#{type}"
        plw = PacketLogWriter.new(remote_log_directory, rt_label)
        @packet_logs["#{scope}__#{target_name}__#{packet_name}__#{type}"] = plw
      end

      reduced = {}
      data_keys = nil
      entry_time = nil
      current_time = nil
      previous_time = nil
      plr = OpenC3::PacketLogReader.new
      plr.each(file.local_path) do |packet|
        # Ignore anything except numbers like STRING or BLOCK items
        data = packet.read_all(:RAW).select { |key, value| value.is_a?(Numeric) }
        converted_data = packet.read_all(:CONVERTED).select { |key, value| value.is_a?(Numeric) }
        # Merge in the converted data which overwrites the raw
        data.merge!(converted_data)

        previous_time = current_time
        current_time = packet.packet_time.to_f
        entry_time ||= current_time
        data_keys ||= data.keys

        # Determine if we've rolled over a entry boundary
        # We have to use current % entry_seconds < previous % entry_seconds because
        # we don't know the data rates. We also have to check for current - previous >= entry_seconds
        # in case the data rate is so slow we don't have multiple samples per entry
        if previous_time &&
             (
               (current_time % entry_seconds < previous_time % entry_seconds) ||
                 (current_time - previous_time >= entry_seconds)
             )
          Logger.debug("Reducer: Roll over entry boundary cur_time:#{current_time}")

          reduce(type, data_keys, reduced)
          plw.write(
            :JSON_PACKET,
            :TLM,
            target_name,
            packet_name,
            entry_time * Time::NSEC_PER_SECOND,
            false,
            JSON.generate(reduced.as_json(:allow_nan => true)),
          )
          # Reset all our sample variables
          entry_time = current_time
          reduced = {}

          # Check to see if we should start a new log file
          # We compare the current entry_time to see if it will push us over
          if plw.first_time &&
               (entry_time - plw.first_time.to_f) >= file_seconds
            Logger.debug("Reducer: (1) start new file! old filename: #{plw.filename}")
            plw.start_new_file # Automatically closes the current file
          end
        end

        # Update statistics for this packet's values
        data.each do |key, value|
          if type == 'minute'
            reduced["#{key}__VALS"] ||= []
            reduced["#{key}__VALS"] << value
            reduced["#{key}_MIN"] ||= value
            reduced["#{key}_MIN"] = value if value < reduced["#{key}_MIN"]
            reduced["#{key}_MAX"] ||= value
            reduced["#{key}_MAX"] = value if value > reduced["#{key}_MAX"]
          else
            reduced[key] ||= value
            reduced[key] = value if key.match(/_MIN$/) && value < reduced[key]
            reduced[key] = value if key.match(/_MAX$/) && value > reduced[key]
            if key.match(/_AVG$/)
              reduced["#{key}__VALS"] ||= []
              reduced["#{key}__VALS"] << value
            end
            if key.match(/_STDDEV$/)
              reduced["#{key}__VALS"] ||= []
              reduced["#{key}__VALS"] << value
            end
            if key.match(/_SAMPLES$/)
              reduced["#{key}__VALS"] ||= []
              reduced["#{key}__VALS"] << value
            end
          end
        end
      end
      file.delete # Remove the local copy

      # See if this last entry should go in a new file
      if plw.first_time &&
        (entry_time - plw.first_time.to_f) >= file_seconds
        Logger.debug("Reducer: (2) start new file! old filename: #{plw.filename}")
        plw.start_new_file # Automatically closes the current file
      end

      # Write out the final data now that the file is done
      reduce(type, data_keys, reduced)
      plw.write(
        :JSON_PACKET,
        :TLM,
        target_name,
        packet_name,
        entry_time * Time::NSEC_PER_SECOND,
        false,
        JSON.generate(reduced.as_json(:allow_nan => true)),
      )
      true
    rescue => e
      if file.local_path and File.exist?(file.local_path)
        Logger.error("Reducer Error: #{filename}:#{File.size(file.local_path)} bytes: \n#{e.formatted}")
      else
        Logger.error("Reducer Error: #{filename}:(Not Retrieved): \n#{e.formatted}")
      end
      false
    end

    def reduce(type, data_keys, reduced)
      # We've collected all the values so calculate the AVG and STDDEV
      if type == 'minute'
        data_keys.each do |key|
          reduced["#{key}_SAMPLES"] = reduced["#{key}__VALS"].length
          reduced["#{key}_AVG"], reduced["#{key}_STDDEV"] =
            Math.stddev_population(reduced["#{key}__VALS"])

          # Remove the raw values as they're only used for AVG / STDDEV calculation
          reduced.delete("#{key}__VALS")
        end
      else
        # Sort so we calculate the average first, then samples, then stddev
        data_keys.sort.each do |key|
          base_name = key.split('_')[0..-2].join('_')
          case key
          when /_AVG$/
            weighted_sum = 0
            samples = reduced["#{base_name}_SAMPLES__VALS"]
            reduced["#{key}__VALS"].each_with_index do |val, i|
              weighted_sum += (val * samples[i])
            end
            reduced[key] = weighted_sum / samples.sum
          when /_SAMPLES$/
            reduced[key] = reduced["#{base_name}_SAMPLES__VALS"].sum
          when /_STDDEV$/
            # Do the STDDEV calc last so we can use the previously calculated AVG
            # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
            samples = reduced["#{base_name}_SAMPLES__VALS"]
            avg = reduced["#{base_name}_AVG__VALS"]
            s2 = 0
            reduced["#{key}__VALS"].each_with_index do |val, i|
              # puts "i:#{i} val:#{val} samples[i]:#{samples[i]} avg[i]:#{avg[i]}"
              s2 += (samples[i] * avg[i]**2 + val**2)
            end

            # Note: For very large numbers with very small deviations this sqrt can fail.
            # If so then just set the stddev to 0.
            begin
              reduced[key] =
                Math.sqrt(s2 / samples.sum - reduced["#{base_name}_AVG"])
            rescue Exception
              reduced[key] = 0.0
            end
          end
        end
        data_keys.each do |key|
          # Remove the raw values as they're only used for AVG / STDDEV calculation
          reduced.delete("#{key}__VALS")
        end
      end
    end
  end
end

OpenC3::ReducerMicroservice.run if __FILE__ == $0
