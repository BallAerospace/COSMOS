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

require 'openc3'
OpenC3.require_file 'openc3/utilities/store'

class TopicsThread
  def initialize(topics, channel, history_count = 0, max_batch_size = 100, offsets: nil, transmit_msg_id: false)
    @topics = topics
    @offsets = offsets
    @channel = channel
    @history_count = history_count.to_i
    @max_batch_size = max_batch_size
    @transmit_msg_id = transmit_msg_id
    @cancel_thread = false
    @thread = nil
    @offset_index_by_topic = {}
    @topics.each_with_index do |topic, index|
      @offset_index_by_topic[topic] = index
    end
  end

  def start
    @thread = Thread.new do
      if !@offsets
        @offsets = Array.new(@topics.length, "0-0")
        thread_setup()
      end
      while true
        break if @cancel_thread
        thread_body()
        break if @cancel_thread
      end
    rescue Redis::CommandError => err
      OpenC3::Logger.error "#{self.class.name} Redis::CommandError\n#{err.formatted}"
      # If we're loading then Redis is just not ready yet so retry
      if err.message.include?("LOADING")
        sleep 5
        retry
      end
    rescue => err
      OpenC3::Logger.error "#{self.class.name} unexpectedly died\n#{err.formatted}"
    ensure
      thread_teardown()
    end
  end

  def stop
    @cancel_thread = true
  end

  def transmit_results(results, force: false)
    if results.length > 0 or force
      # Fortify: This send is intentionally bypassing access control to get to the
      # private transmit method
      @channel.send(:transmit, JSON.generate(results.as_json(:allow_nan => true)))
    end
  end

  def thread_setup
    @topics.each do |topic|
      results = OpenC3::Topic.xrevrange(topic, '+', '-', count: [1, @history_count].max) # Always get at least 1, because 0 breaks redis-rb
      batch = []
      results.reverse_each do |msg_id, msg_hash|
        @offsets[@offset_index_by_topic[topic]] = msg_id
        msg_hash[:msg_id] = msg_id if @transmit_msg_id
        batch << msg_hash
        if batch.length > @max_batch_size
          transmit_results(batch)
          batch.clear
        end
      end
      transmit_results(batch) unless @history_count.zero?
    end
  end

  def thread_body
    results = []
    OpenC3::Topic.read_topics(@topics, @offsets) do |topic, msg_id, msg_hash, redis|
      @offsets[@offset_index_by_topic[topic]] = msg_id
      msg_hash[:msg_id] = msg_id if @transmit_msg_id
      results << msg_hash
      if results.length > @max_batch_size
        transmit_results(results)
        results.clear
      end
      break if @cancel_thread
    end
    transmit_results(results)
  end

  def thread_teardown
    # Define in subclass
  end

end
