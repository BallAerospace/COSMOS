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
require 'cosmos/utilities/s3'
require 'rufus-scheduler'

module Cosmos
  # Architecture of the ReducerMicroservice: Get a list of all the files in logs/SCOPE/reduced_logs/tlm/TGT/PKT/YYYYMMDD
  # Once we know the last file present we know where we left off
  # Now go get all the files in logs/SCOPE/decom_logs/tlm/TGT/PKT/YYYYMMDD corresponding to that latest file
  # Start processing minute data, each minute data completed kick off hour, each hour completed kick off day
  class ReducerMicroservice < Microservice
    MINUTE_METRIC = 'reducer_minute_duration'
    HOUR_METRIC = 'reducer_hour_duration'
    DAY_METRIC = 'reducer_day_duration'

    # How long to wait for any currently running jobs to complete before killing them
    SHUTDOWN_DELAY_SECS = 1

    def run
      @topics.each do |topic|
        scope, _, target_name, packet_name = topic.split('__')
        total_size, oldest_list = S3Utilities.get_total_size_and_oldest_list('logs', "#{@scope}/reduced_logs/tlm/#{target_name}/#{packet_name}")
        puts oldest_list

        total_size, oldest_list = S3Utilities.get_total_size_and_oldest_list('logs', "#{@scope}/decom_logs/tlm/#{target_name}/#{packet_name}")
        puts oldest_list
      end

      # Note it takes several seconds to create the scheduler
      # @scheduler = Rufus::Scheduler.new
      # @scheduler.cron '* * * * *', first: :now do
      #   reduce_minute
      # end
      # @scheduler.cron '0 * * * *', first: :now do
      #   reduce_hour
      # end
      # @scheduler.cron '0 0 * * *', first: :now do
      #   reduce_day
      # end

      # Let the current thread join the scheduler thread and
      #  block until shutdown is called
      # @scheduler.join
    end

    def shutdown
      # @scheduler.shutdown(wait: SHUTDOWN_DELAY_SECS) if @scheduler
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
        file_path =
          FileCache.instance.reserve_file(
            first_object.cmd_or_tlm,
            first_object.target_name,
            first_object.packet_name,
            first_object.start_time,
            file_end_time,
            @stream_mode,
            scope: @scope,
          ) # TODO: look at how @stream_mode is being used
      end
    end

    def reduce_hour
      metric(HOUR_METRIC) do
        # Reducing data to hours requires grabbing from the minute data stream
        @minute_topics.each do |topic|
          process_topic(topic, Time::MSEC_PER_HOUR, HOUR_KEY)
        end
      end
    end

    def reduce_day
      metric(DAY_METRIC) do
        # Reducing data to days requires grabbing from the hour data stream
        @hour_topics.each do |topic|
          process_topic(topic, Time::MSEC_PER_DAY, DAY_KEY)
        end
      end
    end

    def process_topic(topic, time_period, key)
      Logger.debug "Processing #{key} with topic #{topic}"

      # Ensure it's not sitting at 0 which means there is no data in the stream
      if @offsets[topic] == 0
        id, msg = Store.get_oldest_message(topic)
        if msg
          Logger.debug("Oldest message ID:#{id} time:#{ns_ms(msg['time'])}")
          @offsets[topic] = ns_ms(msg['time'])
        else
          return # Still no data in stream, return and wait
        end
      end

      newest_id, msg = Store.get_newest_message(topic)
      newest_time = ns_ms(msg['time'])
      Logger.debug "Newest message ID:#{newest_id}, time:#{newest_time} offset:#{@offsets[topic]}"

      # Keep processing while we have data in the time_period
      while ((newest_time - @offsets[topic]) >= time_period)
        # milliseconds
        # Prepend '(' to the last ID to make the xrange command exclusive (excludes the first value)
        messages =
          Store.xrange(
            topic,
            "(#{@offsets[topic]}",
            @offsets[topic] + time_period,
          )
        process_messages(messages, key)

        # Set the new offset to the last message time
        @offsets[topic] = ns_ms(messages[-1][1]['time'])
      end
    end

    def process_messages(messages, topic_key)
      num_samples = 0
      data = {} # Raw data
      messages.each do |id, msg_hash|
        values = JSON.parse(msg_hash['json_data'])

        # Ignore anything except numbers, this automatically ignores limits, formatted and units values
        values.select! { |key, value| value.is_a?(Numeric) }

        # Reduce to eliminate RAW where a CONVERTED exists
        values.keys.each do |key|
          values[key[0...-3]] = values.delete(key) if key.include?('__C')
        end
        values.each do |key, value|
          data[key] ||= []
          data[key] << value
        end
        if msg_hash['num_samples']
          num_samples = msg_hash['num_samples'].to_i
        else
          num_samples = values.length
        end
      end

      reduced = {}
      total_samples = 0
      data.each do |key, values|
        if topic_key == MINUTE_KEY
          total_samples = values.length
          reduced["#{key}__MIN"] = values.min
          reduced["#{key}__MAX"] = values.max
          reduced["#{key}__AVG"], reduced["#{key}__STDDEV"] =
            Math.stddev_population(values)
        else
          total_samples = num_samples * values.length
          reduced[key] = values.min if key.include?('__MIN')
          reduced[key] = values.max if key.include?('__MAX')

          # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
          if key.include?('__AVG')
            reduced[key] =
              values.sum { |v| v * num_samples } / total_samples.to_f
          end
        end
      end

      # Do the STDDEV calc last so we can use the previously calculated AVG
      if topic_key != MINUTE_KEY
        data
          .keys
          .select { |k| k.include?('__STDDEV') }
          .each do |key|
            values = data[key]

            # puts "key:#{key} vals:#{values} total:#{total_samples}" if key.include?('COLLECTS')
            # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
            avg_key = "#{key[0...-8]}__AVG"
            avg_vals = data[avg_key]

            # puts "avg key:#{avg_key} vals:#{avg_vals} reduced:#{reduced[avg_key]}" if key.include?('COLLECTS')
            s2 = 0
            values.each_with_index do |val, i|
              # puts "i:#{i} std:#{val} avg:#{avg_vals[i]}" if key.include?('COLLECTS')
              s2 += (num_samples * (avg_vals[i]**2 + val**2))
            end

            # puts "s2:#{s2} samples:#{num_samples} total:#{num_samples * values.length}" if key.include?('COLLECTS')
            # Note: For very large numbers with very small deviations this sqrt can fail.  If so then just set the stddev to 0.
            begin
              reduced[key] = Math.sqrt(s2 / total_samples - reduced[avg_key]**2)
            rescue Exception
              reduced[key] = 0.0
            end
          end
      end

      target_name = messages[0][1]['target_name']
      packet_name = messages[0][1]['packet_name']
      msg_hash = {
        time: idi(messages[-1][0]) * 1_000_000, # Convert milliseconds to nanoseconds
        target_name: target_name,
        packet_name: packet_name,
        num_samples: total_samples,
        json_data: JSON.generate(reduced.as_json),
      }
      id = @test ? "#{idi(messages[-1][0])}-0" : nil
      Store.write_topic(
        "#{scope}__#{topic_key}__{#{target_name}}__#{packet_name}",
        msg_hash,
        id,
      )
    end

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
