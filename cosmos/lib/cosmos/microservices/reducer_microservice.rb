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
require 'rufus-scheduler'

module Cosmos
  class ReducerMicroservice < Microservice
    MINUTE_METRIC = "reducer_minute_duration"
    HOUR_METRIC = "reducer_hour_duration"
    DAY_METRIC = "reducer_day_duration"
    MINUTE_KEY = "REDUCED_MINUTE"
    HOUR_KEY = "REDUCED_HOUR"
    DAY_KEY = "REDUCED_DAY"
    REDUCER_KEYS = [MINUTE_KEY, HOUR_KEY, DAY_KEY]
    # How long to wait for any currently running jobs to complete before killing them
    SHUTDOWN_DELAY_SECS = 1

    def run
      @test = false # Set to true to override ID values in Redis for testing
      initialize_streams()
      get_initial_offsets()

      # Note it takes several seconds to create the scheduler
      @scheduler = Rufus::Scheduler.new
      @scheduler.cron '* * * * *' do
        reduce_minute()
      end
      @scheduler.cron '0 * * * *' do
        reduce_hour()
      end
      @scheduler.cron '0 0 * * *' do
        reduce_day()
      end
      # Let the current thread join the scheduler thread and
      #  block until shutdown is called
      @scheduler.join
    end

    def shutdown
      @scheduler.shutdown(wait: SHUTDOWN_DELAY_SECS) if @scheduler
      super()
    end

    def initialize_streams
      new_streams = []
      @topics.each do |topic|
        scope, _, target_name, packet_name = topic.split('__')
        # Set the target for use in the metric ... should only ever be one
        @target ||= target_name
        REDUCER_KEYS.each do |key|
          stream_name = "#{scope}__#{key}__#{target_name}__#{packet_name}"
          new_streams << stream_name unless Store.exists?(stream_name)
        end
      end
      Store.initialize_streams(new_streams)

      @minute_topics = new_streams.select {|stream| stream.include?(MINUTE_KEY) }
      @hour_topics = new_streams.select {|stream| stream.include?(HOUR_KEY) }
    end

    # TODO: This needs work to calculate decom stream offsets in case this process
    # dies and comes back. We need to calculate where to begin based on what's been
    # processed in the reduced minute data.
    def get_initial_offsets
      @offsets = {}
      @topics.each do |topic|
        # Get decom stream offsets
        @offsets[topic] = Store.get_last_offset(topic)

        # Get reduced stream offsets
        scope, _, target_name, packet_name = topic.split('__')
        REDUCER_KEYS.each do |key|
          stream_name = "#{scope}__#{key}__#{target_name}__#{packet_name}"
          @offsets[stream_name] = Store.get_last_offset(stream_name)
        end
      end
    end

    def metric(name)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      @metric.add_sample(name: name, value: elapsed, labels: { "target" => @target })
    end

    def reduce_minute
      metric(MINUTE_METRIC) do
        # Reducing data to minute requires grabbing from the decom topics passed in
        @topics.each do |topic|
          process_topic(topic, Time::MSEC_PER_MINUTE, MINUTE_KEY)
        end
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
      # Ensure it's not sitting at 0-0 which means there is no data in the stream
      if @offsets[topic] == '0-0'
        id, msg = Store.get_oldest_message(topic)
        if msg
          Logger.debug("Oldest message ID:#{id}")
          @offsets[topic] = id
        else
          return # Still no data in stream, return and wait
        end
      end

      newest_id, msg = Store.get_newest_message(topic)
      return unless newest_id
      Logger.debug "Newest message ID:#{newest_id}, offset:#{@offsets[topic]}"
      # Keep processing while we have 60s of data
      while (idi(newest_id) - idi(@offsets[topic])) >= time_period # milliseconds
        messages = Store.xrange(topic, @offsets[topic], idi(@offsets[topic]) + time_period)
        process_messages(messages, key)
        # Prepend '(' to the last ID to make the xrange command exclusive (excludes the first value)
        @offsets[topic] = "(#{messages[-1][0]}"
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
          if key.include?('__C')
            values[key[0...-3]] = values.delete(key)
          end
        end
        values.each do |key, value|
          data[key] ||= []
          data[key] << value
        end
        if msg_hash["num_samples"]
          num_samples = msg_hash["num_samples"].to_i
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
          reduced["#{key}__AVG"], reduced["#{key}__STDDEV"] = Math.stddev_population(values)
        else
          total_samples = num_samples * values.length
          if key.include?("__MIN")
            reduced[key] = values.min
          end
          if key.include?("__MAX")
            reduced[key] = values.max
          end
          # See https://math.stackexchange.com/questions/1547141/aggregating-standard-deviation-to-a-summary-point
          if key.include?("__AVG")
            reduced[key] = values.sum { |v| v * num_samples} / total_samples.to_f
          end
        end
      end
      # Do the STDDEV calc last so we can use the previously calculated AVG
      if topic_key != MINUTE_KEY
        data.keys.select {|k| k.include?("__STDDEV") }.each do |key|
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

      target_name = messages[0][1]["target_name"]
      packet_name = messages[0][1]["packet_name"]
      msg_hash = { time: idi(messages[0][0]) * 1000, # Convert milliseconds to nanoseconds
        target_name: target_name,
        packet_name: packet_name,
        num_samples: total_samples,
        json_data: JSON.generate(reduced.as_json)
      }
      id = @test ? "#{idi(messages[-1][0])}-0" : nil
      Store.write_topic("#{scope}__#{topic_key}__{#{target_name}}__#{packet_name}", msg_hash, id)
    end

    private

    # Return the ID integer (idi) from a Redis Stream ID
    def idi(id)
      # See https://redis.io/topics/streams-intro for more info
      # Stream IDs are formatted as timestamp dash sequence, e.g. 1519073278252-0
      # But when used with XRANGE, we prepend '(' to make it exclusive range interval
      # So get rid of all that stuff and convert to an integer we can do math on
      id.split('-')[0].delete('(').to_i
    end
  end
end

Cosmos::ReducerMicroservice.run if __FILE__ == $0
