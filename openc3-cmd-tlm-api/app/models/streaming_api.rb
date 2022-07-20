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

# TODO : Handoff to realtime thread

require 'base64'
require 'openc3'

OpenC3.require_file 'openc3/packets/packet'
OpenC3.require_file 'openc3/utilities/store'
OpenC3.require_file 'openc3/utilities/s3_file_cache'
OpenC3.require_file 'openc3/packets/json_packet'
OpenC3.require_file 'openc3/logs/packet_log_reader'
OpenC3.require_file 'openc3/utilities/authorization'

class StreamingThread
  def initialize(channel, collection, stream_mode, max_batch_size = 100)
    # OpenC3::Logger.level = OpenC3::Logger::DEBUG
    @channel = channel
    @collection = collection
    @max_batch_size = max_batch_size
    @cancel_thread = false
    @thread = nil
    @stream_mode = stream_mode
  end

  def start
    @thread = Thread.new do
      while true
        break if @cancel_thread
        thread_body()
        break if @cancel_thread
      end
    rescue => err
      OpenC3::Logger.error "#{self.class.name} unexpectedly died\n#{err.formatted}"
    end
  end

  def alive?
    if @thread
      @thread.alive?
    else
      false
    end
  end

  def thread_body
    raise "Must be defined by subclasses"
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

  def redis_thread_body(topics, offsets, objects_by_topic)
    # OpenC3::Logger.debug "#{self.class} redis_thread_body topics:#{topics} offsets:#{offsets} objects:#{objects_by_topic}"
    results = []
    if topics.length > 0
      rtr = OpenC3::Topic.read_topics(topics, offsets) do |topic, msg_id, msg_hash, redis|
        # OpenC3::Logger.debug "read_topics topic:#{topic} offsets:#{offsets} id:#{msg_id} msg time:#{msg_hash['time']}"
        objects = objects_by_topic[topic]
        objects.each do |object|
          object.offset = msg_id
        end
        results_by_value_type = []
        value_types = objects.group_by { |object| object.value_type }
        value_types.each_value do |value|
          results_by_value_type << handle_message(topic, msg_id, msg_hash, redis, value)
        end
        results_by_value_type.compact!
        if results_by_value_type.length > 0
          results.concat(results_by_value_type)
        else
          break results
        end
        if results.length > @max_batch_size
          transmit_results(results)
          results.clear
        end
        break results if @cancel_thread
        results
      end

      # If we're no longer grabbing packets from the stream (empty result)
      # we check to see if we need to continue
      # OpenC3::Logger.debug "rtr:#{rtr} empty?:#{rtr.empty?} results:#{results} topics:#{topics} offsets:#{offsets}"
      if rtr.nil? or rtr.empty?
        topics.each do |topic|
          objects = objects_by_topic[topic]
          objects.each do |object|
            keys = []
            # If time has passed the end_time and we're still not getting anything we're done
            if object.end_time and object.end_time < Time.now.to_nsec_from_epoch
              keys << object.key
              @cancel_thread = true
            end
            @collection.remove(keys)
          end
        end
      end
      transmit_results(results, force: @collection.empty?)
      transmit_results([], force: true) if !results.empty? and @collection.empty?
    else
      sleep(1)
    end
  end

  def handle_message(topic, msg_id, msg_hash, redis, objects)
    topic_without_hashtag = topic.gsub(/{|}/, '') # This removes all curly braces, and we don't allow curly braces in our keys
    first_object = objects[0]
    time = msg_hash['time'].to_i
    if @stream_mode == :RAW
      return handle_raw_packet(msg_hash['buffer'], objects, time, topic_without_hashtag)
    else # @stream_mode == :DECOM
      json_packet = OpenC3::JsonPacket.new(first_object.cmd_or_tlm, first_object.target_name, first_object.packet_name,
        time, OpenC3::ConfigParser.handle_true_false(msg_hash["stored"]), msg_hash["json_data"])
      return handle_json_packet(json_packet, objects, topic_without_hashtag)
    end
  end

  def handle_json_packet(json_packet, objects, topic)
    time = json_packet.packet_time
    keys_remain = objects_active?(objects, time.to_nsec_from_epoch)
    return nil unless keys_remain
    result = {}
    objects.each do |object|
      # OpenC3::Logger.debug("item:#{object.item_name} key:#{object.key} type:#{object.value_type}")
      if object.item_name
        result[object.key] = json_packet.read(object.item_name, object.value_type)
      else # whole packet
        this_packet = json_packet.read_all(object.value_type)
        result = result.merge(this_packet)
        result['packet'] = topic + "__" + object.value_type.to_s
      end
    end
    result['time'] = time.to_nsec_from_epoch
    return result
  end

  def handle_raw_packet(buffer, objects, time, topic)
    keys_remain = objects_active?(objects, time)
    return nil unless keys_remain
    return {
      packet: topic,
      buffer: Base64.encode64(buffer),
      time: time
    }
  end

  def objects_active?(objects, time)
    first_object = objects[0]
    if first_object.end_time and time > first_object.end_time
      # These objects have expired and are removed from the collection
      keys = []
      objects.each do |object|
        keys << object.key
      end
      @collection.remove(keys)
      return false
    end
    return true
  end
end

class LoggedStreamingThread < StreamingThread
  ALLOWABLE_START_TIME_OFFSET_NSEC = 60 * Time::NSEC_PER_SECOND

  def initialize(thread_id, channel, collection, stream_mode, max_batch_size = 100, scope:)
    super(channel, collection, stream_mode, max_batch_size)
    @thread_id = thread_id
    @thread_mode = :SETUP
    # Reduced has no Redis streams so go direct to file
    @thread_mode = :FILE if stream_mode.to_s.upcase.include?("REDUCED")
    @scope = scope
  end

  def thread_body
    objects = @collection.objects_by_thread_id[@thread_id]
    # Cancel if we don't have any objects ... this can happen as things are processed
    # or if someone calls remove() from the StreamingApi
    @cancel_thread = true unless objects and objects.length > 0
    return if @cancel_thread

    first_object = objects[0]
    if @thread_mode == :SETUP
      # Get the newest message because we only stream if there is data after our start time
      _, msg_hash_new = OpenC3::Topic.get_newest_message(first_object.topic)
      # OpenC3::Logger.debug "first time:#{first_object.start_time} newest:#{msg_hash_new['time']}"
      # Allow 1 minute in the future to account for big time discrepancies, which may be caused by:
      #   - the JavaScript client using the machine's local time, which might not be set with NTP
      #   - browser security settings rounding the value within a few milliseconds
      allowable_start_time = first_object.start_time - ALLOWABLE_START_TIME_OFFSET_NSEC
      if msg_hash_new && msg_hash_new['time'].to_i > allowable_start_time
        # Determine oldest timestamp in stream to determine if we need to go to file
        msg_id, msg_hash = OpenC3::Topic.get_oldest_message(first_object.topic)
        oldest_time = msg_hash['time'].to_i
        # OpenC3::Logger.debug "first start time:#{first_object.start_time} oldest:#{oldest_time}"
        if first_object.start_time < oldest_time
          # Stream from Files
          @thread_mode = :FILE
        else
          # Stream from Redis
          # Guesstimate start offset in stream based on first packet time and redis time
          redis_time = msg_id.split('-')[0].to_i * 1_000_000
          delta = redis_time - oldest_time
          # Start streaming from calculated redis time
          offset = ((first_object.start_time + delta) / 1_000_000).to_s + '-0'
          # OpenC3::Logger.debug "stream from Redis offset:#{offset} redis_time:#{redis_time} delta:#{delta}"
          objects.each {|object| object.offset = offset}
          @thread_mode = :STREAM
        end
      else
        # Since we're not going to transmit anything cancel and transmit an empty result
        # OpenC3::Logger.debug "NO DATA DONE! transmit 0 results"
        @cancel_thread = true
        transmit_results([], force: true)
      end
    elsif @thread_mode == :STREAM
      objects_by_topic = { objects[0].topic => objects }
      redis_thread_body([first_object.topic], [first_object.offset], objects_by_topic)
    else # @thread_mode == :FILE
      # Get next file from file cache
      file_end_time = first_object.end_time
      file_end_time = Time.now.to_nsec_from_epoch unless file_end_time
      file_path = S3FileCache.instance.reserve_file(first_object.cmd_or_tlm, first_object.target_name, first_object.packet_name,
        first_object.start_time, file_end_time, @stream_mode, scope: @scope) # TODO: look at how @stream_mode is being used
      if file_path
        file_path_split = File.basename(file_path).split("__")
        file_end_time = DateTime.strptime(file_path_split[1], S3FileCache::TIMESTAMP_FORMAT).to_f * Time::NSEC_PER_SECOND # TODO: get format from different class' constant?

        # Scan forward to find first packet needed
        # Stream forward until packet > end_time or no more packets
        results = []
        plr = OpenC3::PacketLogReader.new()
        topic_without_hashtag = first_object.topic.gsub(/{|}/, '') # This removes all curly braces, and we don't allow curly braces in our keys
        done = plr.each(file_path, false, Time.from_nsec_from_epoch(first_object.start_time), Time.from_nsec_from_epoch(first_object.end_time)) do |packet|
          time = packet.received_time if packet.respond_to? :received_time
          time ||= packet.packet_time
          result = nil
          if @stream_mode == :RAW
            result = handle_raw_packet(packet.buffer, objects, time.to_nsec_from_epoch, topic_without_hashtag)
          else # @stream_mode == :DECOM
            result = handle_json_packet(packet, objects, topic_without_hashtag)
          end
          if result
            results << result
          else
            break
          end
          if results.length > @max_batch_size
            transmit_results(results)
            results.clear
          end
          break if @cancel_thread
        end
        transmit_results(results)
        @last_file_redis_offset = plr.redis_offset

        # Move to the next file
        S3FileCache.instance.unreserve_file(file_path)
        objects.each {|object| object.start_time = file_end_time}

        if done # We reached the end time
          @cancel_thread = true
          transmit_results([], force: true)
        end
      else
        OpenC3::Logger.info "Switch stream from file to Redis"
        # TODO: What if there is no new data in the Redis stream?

        # Switch to stream from Redis
        # Determine oldest timestamp in stream
        msg_id, msg_hash = OpenC3::Topic.get_oldest_message(first_object.topic)
        if msg_hash
          oldest_time = msg_hash['time'].to_i
          # Stream from Redis
          offset = @last_file_redis_offset if @last_file_redis_offset
          if !offset
            # Guesstimate start offset in stream based on first packet time and redis time
            redis_time = msg_id.split('-')[0].to_i * 1000000
            delta = redis_time - oldest_time
            # Start streaming from calculated redis time
            offset = ((first_object.start_time + delta) / 1_000_000).to_s + '-0'
          end
          OpenC3::Logger.debug "Oldest Redis id:#{msg_id} msg time:#{oldest_time} last object time:#{first_object.start_time} offset:#{offset}"
          objects.each {|object| object.offset = offset}
          @thread_mode = :STREAM
        else
          @cancel_thread = true
        end
      end
    end

    # Transfers item to realtime thread when complete (if continued)
    # Needs to mutex transfer
    #   checks if equal offset if packet already exists in realtime
    #   if doesn't exist adds with item offset
    #   if does exist and equal - transfer
    #   if does exist and less than - add item with less offset
    #   if does exist and greater than - catch up and try again
  end
end

class RealtimeStreamingThread < StreamingThread
  def thread_body
    topics, offsets, objects_by_topic = @collection.realtime_topics_offsets_and_objects
    redis_thread_body(topics, offsets, objects_by_topic)
  end
end

class StreamingApi
  include OpenC3::Authorization

  # Helper class to store information about the streaming item
  class StreamingObject
    include OpenC3::Authorization
    attr_accessor :key
    attr_accessor :cmd_or_tlm
    attr_accessor :target_name
    attr_accessor :packet_name
    attr_accessor :item_name
    attr_accessor :value_type
    attr_accessor :start_time
    attr_accessor :end_time
    attr_accessor :offset
    attr_accessor :topic
    attr_accessor :thread_id

    def initialize(key, start_time, end_time, thread_id = nil, stream_mode:, scope:, token: nil)
      @key = key
      key_split = key.split('__')
      @cmd_or_tlm = key_split[0].to_s.intern
      @scope = scope
      @target_name = key_split[1]
      @packet_name = key_split[2]
      type = nil
      if stream_mode == :RAW
        # value_type is implied to be :RAW and this must be a whole packet
        @value_type = :RAW
        type = (@cmd_or_tlm == :CMD) ? 'COMMAND' : 'TELEMETRY'
      elsif stream_mode == :DECOM
        type = (@cmd_or_tlm == :CMD) ? 'DECOMCMD' : 'DECOM'
        # If our value type is the 4th param we're streaming a packet, otherwise item
        if OpenC3::Packet::VALUE_TYPES.include?(key_split[3].intern)
          @value_type = key_split[3].intern
        else
          @item_name = key_split[3]
          @value_type = key_split[4].intern
        end
      else # Reduced
        type = stream_mode
        # Reduced items are passed as TGT__PKT__ITEM_REDUCETYPE__VALUETYPE
        # e.g. INST__HEALTH_STATUS__TEMP1_AVG__CONVERTED
        # Note there is NOT a double underscore between item name and reduce type
        @item_name = key_split[3]
        @value_type = key_split[4].intern
      end
      @start_time = start_time
      @end_time = end_time
      authorize(permission: @cmd_or_tlm.to_s.downcase, target_name: @target_name, packet_name: @packet_name, scope: scope, token: token)
      @topic = "#{@scope}__#{type}__{#{@target_name}}__#{@packet_name}"
      @offset = nil
      @offset = OpenC3::Topic.get_last_offset(@topic) unless @start_time
      OpenC3::Logger.info("Streaming from #{@topic} start:#{@start_time} end:#{@end_time} offset:#{@offset}")
      @thread_id = thread_id
    end
  end

  # Helper class to collect StreamingObjects and map them to threads
  class StreamingObjectCollection
    attr_reader :objects_by_thread_id

    def initialize
      @objects_by_key = {}
      @objects_by_thread_id = {}
      @objects_by_thread_id[nil] = []
      @mutex = Mutex.new
    end

    def add(objects)
      @mutex.synchronize do
        objects.each do |object|
          existing_object = @objects_by_key[object.key]
          if existing_object
            @objects_by_thread_id[existing_object.thread_id].delete(existing_object)
          end
          @objects_by_key[object.key] = object
          @objects_by_thread_id[object.thread_id] ||= []
          @objects_by_thread_id[object.thread_id] << object
        end
      end
    end

    def remove(keys)
      @mutex.synchronize do
        keys.each do |key|
          object = @objects_by_key[key]
          if object
            @objects_by_key.delete(key)
            @objects_by_thread_id[object.thread_id].delete(object)
          end
        end
      end
    end

    def realtime_topics_offsets_and_objects
      topics_and_offsets = {}
      objects_by_topic = {}
      @mutex.synchronize do
        @objects_by_thread_id[nil].each do |object|
          if object.start_time == nil
            offset = topics_and_offsets[object.topic]
            topics_and_offsets[object.topic] = object.offset if !offset or object.offset < offset
            objects_by_topic[object.topic] ||= []
            objects_by_topic[object.topic] << object
          end
        end
      end
      return topics_and_offsets.keys, topics_and_offsets.values, objects_by_topic
    end

    def length
      return @objects_by_key.length
    end

    def empty?
      length() == 0
    end
  end

  def initialize(uuid, channel, scope: nil, token: nil)
    authorize(permission: 'tlm', scope: scope, token: token)
    @thread_id = 1
    @uuid = uuid
    @channel = channel
    @mutex = Mutex.new
    @collection = StreamingObjectCollection.new
    @realtime_thread = nil
    @logged_threads = []
    # OpenC3::Logger.level = OpenC3::Logger::DEBUG
  end

  def add(data)
    # OpenC3::Logger.debug "start:#{Time.at(data["start_time"].to_i/1_000_000_000.0).formatted}" if data["start_time"]
    # OpenC3::Logger.debug "end:#{Time.at(data["end_time"].to_i/1_000_000_000.0).formatted}" if data["end_time"]
    @mutex.synchronize do
      start_time = nil
      start_time = data["start_time"].to_i if data["start_time"]
      end_time = nil
      end_time = data["end_time"].to_i if data["end_time"]
      stream_mode = data["mode"].to_s.intern
      scope = data["scope"]
      token = data["token"]
      keys = []
      keys.concat(data["items"]) if data["items"]
      keys.concat(data["packets"]) if data["packets"]
      objects = []
      objects_by_topic = {}
      keys.each do |key|
        object = StreamingObject.new(key, start_time, end_time, stream_mode: stream_mode, scope: scope, token: token)
        objects_by_topic[object.topic] ||= []
        objects_by_topic[object.topic] << object
        objects << object
      end
      if start_time
        objects_by_topic.each do |topic, objects|
          # OpenC3::Logger.debug "topic:#{topic} objs:#{objects} mode:#{stream_mode}"
          objects.each {|object| object.thread_id = @thread_id}
          thread = LoggedStreamingThread.new(@thread_id, @channel, @collection, stream_mode, scope: scope)
          thread.start
          @logged_threads << thread
          @thread_id += 1
        end
      elsif end_time.nil? or end_time > Time.now.to_nsec_from_epoch
        # Create a single realtime streaming thread to use the entire collection
        if @realtime_thread.nil?
          @realtime_thread = RealtimeStreamingThread.new(@channel, @collection, stream_mode)
          @realtime_thread.start
        end
      end
      @collection.add(objects)
    end
  end

  def remove(data)
    keys = []
    keys.concat(data["items"]) if data["items"]
    keys.concat(data["packets"]) if data["packets"]
    @collection.remove(keys)
  end

  def kill
    threads = []
    if @realtime_thread
      @realtime_thread.stop
      threads << @realtime_thread
    end
    @logged_threads.each do |thread|
      thread.stop
      threads << thread
    end
    # Allow the threads a chance to stop (1.1s each)
    threads.each do |thread|
      i = 0
      while thread.alive? or i < 110 do
        sleep 0.01
        i += 1
      end
    end
    # Ok we tried, now initialize everything
    @realtime_thread = nil
    @logged_threads = []
  end
end
