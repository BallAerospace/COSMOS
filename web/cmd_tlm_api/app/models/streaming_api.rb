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

# TODO : Handoff to realtime thread

require 'base64'
require 'fileutils'
require 'cosmos'
require 'cosmos/utilities/s3'

Cosmos.require_file 'cosmos/utilities/store'
Cosmos.require_file 'cosmos/packets/json_packet'
Cosmos.require_file 'cosmos/packet_logs/packet_log_reader'
Cosmos.require_file 'cosmos/utilities/authorization'

class FileCacheFile
  attr_reader :s3_path
  attr_reader :local_path
  attr_reader :reservation_count
  attr_reader :size
  attr_reader :error
  attr_accessor :priority

  def initialize(s3_path, size, priority)
    @s3_path = s3_path
    @local_path = nil
    @reservation_count = 0
    @size = size
    @priority = priority
    @error = nil
    @mutex = Mutex.new
  end

  def retrieve
    begin
      rubys3_client = Aws::S3::Client.new
      local_path = "#{FileCache.instance.cache_dir}/#{File.basename(@s3_path)}"
      Cosmos::Logger.info("Retrieving #{@s3_path} from logs bucket")
      #Cosmos::Logger.debug "Retrieving #{@s3_path} from logs bucket"
      rubys3_client.get_object(bucket: "logs", key: @s3_path, response_target: local_path)
      if File.exist?(local_path)
        @size = File.size(local_path)
        @local_path = local_path
      end
      Cosmos::Logger.info("Successfully retrieved #{@s3_path} from logs bucket")
      #Cosmos::Logger.debug "Successfully retrieved #{@s3_path} from logs bucket"
    rescue => err
      @error = err
      Cosmos::Logger.error("Failed to retreive #{@s3_path}\n#{err.formatted}")
      #Cosmos::Logger.debug "Failed to retreive #{@s3_path}\n#{err.formatted}"
    end
  end

  def reserve
    @mutex.synchronize do
      @reservation_count += 1
    end
  end

  def unreserve
    @mutex.synchronize do
      @reservation_count -= 1
      delete() if @reservation_count <= 0
    end
  end

  # private

  def delete
    if @local_path and File.exist?(local_path)
      File.delete(@local_path)
      @local_path = nil
    end
  end
end

class FileCacheFileCollection
  def initialize
    @array = []
    @mutex = Mutex.new
  end

  def add(s3_path, size, priority)
    @mutex.synchronize do
      @array.each do |file|
        if file.s3_path == s3_path
          file.priority = priority if priority < file.priority
          @array.sort! {|a,b| a.priority <=> b.priority}
          return file
        end
      end
      file = FileCacheFile.new(s3_path, size, priority)
      @array << file
      @array.sort! {|a,b| a.priority <=> b.priority}
      return file
    end
  end

  def length
    @array.length
  end

  def get(local_path)
    @mutex.synchronize do
      @array.each do |file|
        return file if file.local_path == local_path
      end
    end
    return nil
  end

  def get_next_to_retrieve
    @mutex.synchronize do
      @array.each do |file|
        return file unless file.local_path
      end
    end
    return nil
  end

  def current_disk_usage
    @mutex.synchronize do
      total_size = 0
      @array.each do |file|
        total_size += file.size if file.local_path
      end
      return total_size
    end
  end
end

class FileCache
  MAX_DISK_USAGE = 20_000_000_000 # 20 GB

  attr_reader :cache_dir

  @@instance = nil
  @@mutex = Mutex.new

  def self.instance
    return @@instance if @@instance
    @@mutex.synchronize do
      @@instance ||= FileCache.new
    end
    @@instance
  end

  def initialize(name = 'default', max_disk_usage = MAX_DISK_USAGE)
    @max_disk_usage = max_disk_usage

    # Create local file cache location
    @cache_dir = File.join(Dir.tmpdir, 'cosmos', 'file_cache', name)
    FileUtils.mkdir_p(@cache_dir)

    # Clear out local file cache
    FileUtils.rm_f Dir.glob("#{@cache_dir}/*")

    @cached_files = FileCacheFileCollection.new

    @thread = Thread.new do
      begin
        while true
          file = @cached_files.get_next_to_retrieve
          #Cosmos::Logger.debug "Next file: #{file}"
          if file and (file.size + @cached_files.current_disk_usage()) <= @max_disk_usage
            file.retrieve
          else
            sleep(1)
          end
        end
      rescue => err
        Cosmos::Logger.error "FileCache thread unexpectedly died\n#{err.formatted}"
      end
    end
  end

  def reserve_file(cmd_or_tlm, target_name, packet_name, start_time_nsec, end_time_nsec, type = :DECOM, timeout = 60, scope:)
    rubys3_client = Aws::S3::Client.new

    # Get List of Files from S3
    total_resp = []
    token = nil
    dates = []
    cur_date = Time.at(start_time_nsec / Time::NSEC_PER_SECOND).beginning_of_day
    end_date = Time.at(end_time_nsec / Time::NSEC_PER_SECOND).beginning_of_day
    while cur_date <= end_date
      dates << cur_date.strftime "%Y%m%d"
      cur_date += 1.day
    end
    dates.each do |date|
      while true
        resp = rubys3_client.list_objects_v2({
          bucket: "logs",
          max_keys: 1000,
          prefix: "#{scope}/#{type.to_s.downcase}logs/#{cmd_or_tlm.to_s.downcase}/#{target_name}/#{packet_name}/#{date}",
          continuation_token: token
        })
        total_resp.concat(resp.contents)
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end
    end

    # Add to needed files
    files = []
    total_resp.each_with_index do |item, index|
      s3_path = item.key
      if file_in_time_range(s3_path, start_time_nsec, end_time_nsec)
        file = @cached_files.add(s3_path, item.size, index)
        #Cosmos::Logger.debug file.inspect
        files << file
      end
    end

    # Wait for first file retrieval
    if files.length > 0
      wait_start = Time.now
      file = files[0]
      file.reserve
      while (Time.now - wait_start) < timeout
        return file.local_path if file.local_path
        sleep(1)
      end

      # Remove reservations if we timeout
      file.unreserve
    end

    return nil
  end

  def unreserve_file(filename)
    @@mutex.synchronize do
      file = @cached_files.get(filename)
      file.unreserve if file
    end
  end

  # private

  def file_in_time_range(s3_path, start_time_nsec, end_time_nsec)
    timestamp_format = "%Y%m%d%S%N" # TODO: get from class constant elsewhere?
    basename = File.basename(s3_path)
    file_start_timestamp, file_end_timestamp, other = basename.split("__")
    file_start_time_nsec = Time.strptime(file_start_timestamp, timestamp_format).to_f * Time::NSEC_PER_SECOND
    file_end_time_nsec = Time.strptime(file_end_timestamp, timestamp_format).to_f * Time::NSEC_PER_SECOND
    if (start_time_nsec < file_end_time_nsec) and (end_time_nsec >= file_start_time_nsec)
      return true
    else
      return false
    end
  end
end

class StreamingThread
  def initialize(channel, collection, stream_mode, max_batch_size = 100)
    # Cosmos::Logger.level = Cosmos::Logger::DEBUG
    # Cosmos::Logger.stdout = true
    @channel = channel
    @collection = collection
    @max_batch_size = max_batch_size
    @cancel_thread = false
    @thread = nil
    @stream_mode = stream_mode
  end

  def start
    @thread = Thread.new do
      begin
        while true
          break if @cancel_thread
          thread_body()
          break if @cancel_thread
        end
      rescue => err
        Cosmos::Logger.error "#{self.class.name} unexpectedly died\n#{err.formatted}"
      end
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
      @channel.send(:transmit, JSON.generate(results.as_json))
    end
  end

  def redis_thread_body(topics, offsets, objects_by_topic)
    # Cosmos::Logger.debug "#{self.class} redis_thread_body topics:#{topics} offsets:#{offsets} objects:#{objects_by_topic}"
    results = []
    if topics.length > 0
      rtr = Cosmos::Store.instance.read_topics(topics, offsets) do |topic, msg_id, msg_hash, redis|
        # Cosmos::Logger.debug "read_topics topic:#{topic} offsets:#{offsets} id:#{msg_id} msg time:#{msg_hash['time']}"
        objects = objects_by_topic[topic]
        objects.each do |object|
          object.offset = msg_id
        end
        result = handle_message(topic, msg_id, msg_hash, redis, objects)
        if result
          results << result
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
      # Cosmos::Logger.debug "rtr:#{rtr} empty?:#{rtr.empty?} results:#{results} topics:#{topics} offsets:#{offsets}"
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
    first_object = objects[0]
    time = msg_hash['time'].to_i
    if @stream_mode == :RAW
      if first_object.end_time and time > first_object.end_time
        # These objects are done - and the thread is done
        remove_object_keys(objects)
        return nil
      end
      return {
        packet: topic,
        buffer: Base64.encode64(msg_hash['buffer']),
        time: time
      }
    else # @stream_mode == :DECOM
      json_packet = Cosmos::JsonPacket.new(first_object.cmd_or_tlm, first_object.target_name, first_object.packet_name,
        time, Cosmos::ConfigParser.handle_true_false(msg_hash["stored"]), msg_hash["json_data"])
      return handle_json_packet(json_packet, objects)
    end
  end

  def handle_json_packet(json_packet, objects)
    first_object = objects[0]
    time = json_packet.packet_time
    if first_object.end_time and time.to_nsec_from_epoch > first_object.end_time
      # These objects are done - and the thread is done
      remove_object_keys(objects)
      return nil
    end
    result = {}
    objects.each do |object|
      if object.item_name
        result[object.key] = json_packet.read(object.item_name, object.value_type)
      else # whole packet
        this_packet = json_packet.read_all(object.value_type)
        result = result.merge(this_packet)
      end
    end
    result['time'] = time.to_nsec_from_epoch
    return result
  end

  def remove_object_keys(objects)
    keys = []
    objects.each do |object|
      keys << object.key
    end
    @collection.remove(keys)
  end
end

class LoggedStreamingThread < StreamingThread
  ALLOWABLE_START_TIME_OFFSET_NSEC = 60 * Time::NSEC_PER_SECOND

  def initialize(thread_id, channel, collection, max_batch_size = 100, scope:)
    super(channel, collection, max_batch_size)
    @thread_id = thread_id
    @thread_mode = :SETUP
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
      _, msg_hash_new = Cosmos::Store.instance.get_newest_message(first_object.topic)
      # Cosmos::Logger.debug "first time:#{first_object.start_time} newest:#{msg_hash_new['time']}"
      # Allow 1 minute in the future to account for big time discrepancies
      allowable_start_time = first_object.start_time - ALLOWABLE_START_TIME_OFFSET_NSEC
      if msg_hash_new && msg_hash_new['time'].to_i > allowable_start_time
        # Determine oldest timestamp in stream to determine if we need to go to file
        msg_id, msg_hash = Cosmos::Store.instance.get_oldest_message(first_object.topic)
        oldest_time = msg_hash['time'].to_i
        # Cosmos::Logger.debug "first start time:#{first_object.start_time} oldest:#{oldest_time}"
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
          objects.each {|object| object.offset = offset}
          @thread_mode = :STREAM
        end
      else
        # Since we're not going to transmit anything cancel and transmit an empty result
        # Cosmos::Logger.debug "NO DATA DONE! transmit 0 results"
        @cancel_thread = true
        transmit_results([], force: true)
      end
    elsif @thread_mode == :STREAM
      objects_by_topic = {objects[0].topic => objects}
      redis_thread_body([first_object.topic], [first_object.offset], objects_by_topic)
    else # @thread_mode == :FILE
      # Get next file from file cache
      file_end_time = first_object.end_time
      file_end_time = Time.now.to_nsec_from_epoch unless file_end_time
      file_path = FileCache.instance.reserve_file(first_object.cmd_or_tlm, first_object.target_name, first_object.packet_name, first_object.start_time, file_end_time, @stream_mode, scope: @scope) # TODO: look at how @stream_mode is being used
      # puts file_path
      if file_path
        file_path_split = File.basename(file_path).split("__")
        file_end_time = file_path_split[1].to_i
        # Cosmos::Logger.debug("file:#{file_path} end:#{file_end_time}")

        # Scan forward to find first packet needed
        # Stream forward until packet > end_time or no more packets
        results = []
        plr = Cosmos::PacketLogReader.new()
        plr.each(file_path, true, Time.from_nsec_from_epoch(first_object.start_time), Time.from_nsec_from_epoch(first_object.end_time)) do |json_packet|
          result = handle_json_packet(json_packet, objects)
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

        # Move to the next file
        FileCache.instance.unreserve_file(file_path)
        objects.each {|object| object.start_time = file_end_time}
      else
        Cosmos::Logger.info("Switch stream from file to Redis")
        # TODO: What if there is no new data in the Redis stream?

        # Switch to stream from Redis
        # Determine oldest timestamp in stream
        msg_id, msg_hash = Cosmos::Store.instance.get_oldest_message(first_object.topic)
        if msg_hash
          oldest_time = msg_hash['time'].to_i
          # Stream from Redis
          # Guesstimate start offset in stream based on first packet time and redis time
          redis_time = msg_id.split('-')[0].to_i * 1000000
          delta = redis_time - oldest_time
          # Start streaming from calculated redis time
          offset = ((first_object.start_time + delta) / 1_000_000).to_s + '-0'
          Cosmos::Logger.debug("Oldest Redis id:#{msg_id} msg time:#{oldest_time} last object time:#{first_object.start_time} offset:#{offset}")
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
    # puts "topics:#{topics} offsets:#{offsets} objects:#{objects_by_topic}"
    redis_thread_body(topics, offsets, objects_by_topic)
  end
end

class StreamingApi
  include Cosmos::Authorization

  # Helper class to store information about the streaming item
  class StreamingObject
    include Cosmos::Authorization
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
      else
        # value_type must be specified and this might be a whole packet or just an item
        @value_type = key_split[-1].to_s.intern
        type = (@cmd_or_tlm == :CMD) ? 'DECOMCMD' : 'DECOM'
        if key_split.length > 4
          @item_name = key_split[3]
        end
      end
      @start_time = start_time
      @end_time = end_time
      authorize(permission: @cmd_or_tlm.to_s.downcase, target_name: @target_name, packet_name: @packet_name, scope: scope, token: token)
      @topic = "#{@scope}__#{type}__#{@target_name}__#{@packet_name}"
      @offset = nil
      @offset = Cosmos::Store.instance.get_last_offset(topic) unless @start_time
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
  end

  def add(data)
    # Cosmos::Logger.info "start:#{Time.at(data["start_time"].to_i/1_000_000_000.0).formatted}" if data["start_time"]
    # Cosmos::Logger.info "end:#{Time.at(data["end_time"].to_i/1_000_000_000.0).formatted}" if data["end_time"]
    @mutex.synchronize do
      start_time = nil
      start_time = data["start_time"].to_i if data["start_time"]
      end_time = nil
      end_time = data["end_time"].to_i if data["end_time"]
      stream_mode = data["mode"].to_s.intern
      # @stream_mode = stream_mode
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
      while (thread.alive? or i < 110) do
        sleep 0.01
        i += 1
      end
    end
    # Ok we tried, now initialize everything
    @realtime_thread = nil
    @logged_threads = []
  end
end
