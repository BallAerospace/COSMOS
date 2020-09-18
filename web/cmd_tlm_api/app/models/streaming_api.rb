# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# TODO : Handoff to realtime thread

require 'fileutils'
require 'cosmos'
require 'aws-sdk-s3'

Cosmos.require_file 'cosmos/utilities/store'
Cosmos.require_file 'cosmos/packets/json_packet'
Cosmos.require_file 'cosmos/packet_logs/packet_log_reader'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos_minio:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

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
      #STDOUT.puts "Retrieving #{@s3_path} from logs bucket"
      rubys3_client.get_object(bucket: "logs", key: @s3_path, response_target: local_path)
      if File.exist?(local_path)
        @size = File.size(local_path)
        @local_path = local_path
      end
      Cosmos::Logger.info("Successfully retrieved #{@s3_path} from logs bucket")
      #STDOUT.puts "Successfully retrieved #{@s3_path} from logs bucket"
    rescue => err
      @error = err
      Cosmos::Logger.error("Failed to retreive #{@s3_path}\n#{err.formatted}")
      #STDOUT.puts "Failed to retreive #{@s3_path}\n#{err.formatted}"
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
  MAX_DISK_USAGE = 20000000000 # 20 GB

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
          #STDOUT.puts "Next file: #{file}"
          if file and (file.size + @cached_files.current_disk_usage()) <= @max_disk_usage
            file.retrieve
          else
            sleep(1)
          end
        end
      rescue => err
        Cosmos::Logger.error "FileCache thread unexpectedly died\n#{err.formatted}"
        #STDOUT.puts "FileCache thread unexpectedly died\n#{err.formatted}"
      end
    end
  end

  def reserve_file(cmd_or_tlm, target_name, packet_name, start_time_nsec, end_time_nsec, type = :DECOM, timeout = 60, scope:)
    rubys3_client = Aws::S3::Client.new

    # Get List of Files from S3
    total_resp = []
    token = nil
    while true
      resp = rubys3_client.list_objects_v2({
        bucket: "logs",
        max_keys: 1000,
        prefix: "#{scope}/#{type.to_s.downcase}logs/#{cmd_or_tlm.to_s.downcase}/#{target_name}/#{packet_name}/",
        continuation_token: token
      })
      total_resp.concat(resp.contents)
      break unless resp.is_truncated
      token = resp.next_continuation_token
    end

    # Add to needed files
    files = []
    total_resp.each_with_index do |item, index|
      s3_path = item.key
      if file_in_time_range(s3_path, start_time_nsec, end_time_nsec)
        file = @cached_files.add(s3_path, item.size, index)
        #STDOUT.puts file.inspect
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
    basename = File.basename(s3_path)
    file_start_time_nsec, file_end_time_nsec, other = basename.split("__")
    file_start_time_nsec = file_start_time_nsec.to_i
    file_end_time_nsec = file_end_time_nsec.to_i
    if (start_time_nsec < file_end_time_nsec) and (end_time_nsec >= file_start_time_nsec)
      return true
    else
      return false
    end
  end
end

class StreamingThread
  def initialize(channel, collection, max_batch_size = 100)
    @channel = channel
    @collection = collection
    @max_batch_size = max_batch_size
    @cancel_thread = false
    @thread = nil
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
        #STDOUT.puts "#{self.class.name} unexpectedly died\n#{err.formatted}"
        Cosmos::Logger.error "#{self.class.name} unexpectedly died\n#{err.formatted}"
      end
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

  def redis_thread_body(topics, offsets, items_by_topic)
    results = []
    if topics.length > 0
      #STDOUT.puts topics.inspect, offsets.inspect
      Cosmos::Store.instance.read_topics(topics, offsets) do |topic, msg_id, msg_hash, redis|
        #STDOUT.puts msg_hash.inspect
        items = items_by_topic[topic]
        items.each do |item|
          item.offset = msg_id
        end
        result = handle_message(topic, msg_id, msg_hash, redis, items)
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
    else
      sleep(1)
    end
  end

  def handle_message(topic, msg_id, msg_hash, redis, items)
    first_item = items[0]
    time = msg_hash['time'].to_i
    json_packet = Cosmos::JsonPacket.new(first_item.cmd_or_tlm, first_item.target_name, first_item.packet_name, time, Cosmos::ConfigParser.handle_true_false(msg_hash["stored"]), msg_hash["json_data"])
    return handle_json_packet(json_packet, items)
  end

  def handle_json_packet(json_packet, items)
    first_item = items[0]
    time = json_packet.packet_time
    if first_item.end_time and time.to_nsec_from_epoch > first_item.end_time
      # These items are done - and the thread is done
      item_keys = []
      items.each do |item|
        item_keys << item.key
      end
      @collection.remove(item_keys)
      return nil
    end
    result = {}
    items.each do |item|
      result[item.key] = json_packet.read(item.item_name, item.value_type)
    end
    result['time'] = time.to_nsec_from_epoch
    return result
  end
end

class StreamingItem
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

  def initialize(key, start_time, end_time, thread_id = nil, scope:)
    @key = key
    key_split = key.split('__')
    @cmd_or_tlm = key_split[0].to_s.intern
    @scope = scope
    @target_name = key_split[1]
    @packet_name = key_split[2]
    @item_name = key_split[3]
    @value_type = key_split[4].to_s.intern
    @start_time = start_time
    @end_time = end_time
    type = (@cmd_or_tlm == :CMD) ? 'DECOMCMD' : 'DECOM'
    @topic = "#{@scope}__#{type}__#{@target_name}__#{@packet_name}"
    @offset = nil
    @offset = Cosmos::Store.instance.get_last_offset(topic) unless @start_time
    @thread_id = thread_id
  end
end

class StreamingItemCollection
  attr_reader :items_by_thread_id

  def initialize
    @items_by_key = {}
    @items_by_thread_id = {}
    @items_by_thread_id[nil] = []
    @mutex = Mutex.new
  end

  def add(items)
    @mutex.synchronize do
      items.each do |item|
        existing_item = @items_by_key[item.key]
        if existing_item
          @items_by_thread_id[existing_item.thread_id].delete(existing_item)
        end
        @items_by_key[item.key] = item
        @items_by_thread_id[item.thread_id] ||= []
        @items_by_thread_id[item.thread_id] << item
      end
    end
  end

  def remove(item_keys)
    @mutex.synchronize do
      item_keys.each do |item_key|
        item = @items_by_key[item_key]
        if item
          @items_by_key.delete(item_key)
          if item.thread_id
            @items_by_thread_id[item.thread_id].delete(item)
          end
        end
      end
    end
  end

  def realtime_topics_offsets_and_items
    topics_and_offsets = {}
    items_by_topic = {}
    @mutex.synchronize do
      @items_by_thread_id[nil].each do |item|
        if item.start_time == nil
          offset = topics_and_offsets[item.topic]
          topics_and_offsets[item.topic] = item.offset if !offset or item.offset < offset
          items_by_topic[item.topic] ||= []
          items_by_topic[item.topic] << item
        end
      end
      return topics_and_offsets.keys, topics_and_offsets.values, items_by_topic
    end
  end

  def length
    return @items_by_key.length
  end
end

class LoggedStreamingThread < StreamingThread
  def initialize(thread_id, channel, collection, max_batch_size = 100, scope:)
    super(channel, collection, max_batch_size)
    @thread_id = thread_id
    @mode = :SETUP
    @scope = scope
  end

  def thread_body
    items = @collection.items_by_thread_id[@thread_id]
    if items and items.length > 0
      first_item = items[0]
      if @mode == :SETUP
        # Determine oldest timestamp in stream
        msg_id, msg_hash = Cosmos::Store.instance.get_oldest_message(first_item.topic)
        if msg_hash
          oldest_time = msg_hash['time'].to_i
          if first_item.start_time < oldest_time
            # Stream from Files
            @mode = :FILE
          else
            # Stream from Redis
            # Guesstimate start offset in stream based on first packet time and redis time
            redis_time = msg_id.split('-')[0].to_i * 1000000
            delta = redis_time - oldest_time
            # Start streaming from calculated redis time
            offset = ((first_item.start_time + delta) / 1000000).to_s + '-0'
            items.each {|item| item.offset = offset}
            @mode = :STREAM
          end
        else
          @cancel_thread = true
        end
      elsif @mode == :STREAM
        items_by_topic = {items[0].topic => items}
        redis_thread_body([first_item.topic], [first_item.offset], items_by_topic)
      else # @mode == :FILE
        # Get next file from file cache
        file_end_time = first_item.end_time
        file_end_time = Time.now.to_nsec_from_epoch unless file_end_time
        file_path = FileCache.instance.reserve_file(first_item.cmd_or_tlm, first_item.target_name, first_item.packet_name, first_item.start_time, file_end_time, scope: @scope)
        #STDOUT.puts file_path
        if file_path
          file_path_split = file_path.split("__")
          file_start_time = file_path_split[0].to_i
          file_end_time = file_path_split[1].to_i

          # Scan forward to find first packet needed
          # Stream forward until packet > end_time or no more packets
          results = []
          plr = Cosmos::PacketLogReader.new()
          plr.each(file_path, true, Time.from_nsec_from_epoch(first_item.start_time), Time.from_nsec_from_epoch(first_item.end_time)) do |json_packet|
            result = handle_json_packet(json_packet, items)
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
          items.each {|item| item.start_time = file_end_time}
        else
          # Switch to stream from Redis
          # Determine oldest timestamp in stream
          msg_id, msg_hash = Cosmos::Store.instance.get_oldest_message(first_item.topic)
          if msg_hash
            oldest_time = msg_hash['time'].to_i
            # Stream from Redis
            # Guesstimate start offset in stream based on first packet time and redis time
            redis_time = msg_id.split('-')[0].to_i * 1000000
            delta = redis_time - oldest_time
            # Start streaming from calculated redis time
            offset = ((first_item.start_time + delta) / 1000000).to_s + '-0'
            items.each {|item| item.offset = offset}
            @mode = :STREAM
          else
            @cancel_thread = true
          end
        end
      end
    else
      @cancel_thread = true
      # Empty set indicates end of all items in collection
      if @collection.length <= 0
        transmit_results([], force: true)
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
    topics, offsets, items_by_topic = @collection.realtime_topics_offsets_and_items
    #STDOUT.puts "Realtime thread: #{topics}, #{offsets}"
    redis_thread_body(topics, offsets, items_by_topic)
  end
end

class StreamingApi
  def initialize(uuid, channel)
    @thread_id = 1
    @uuid = uuid
    @channel = channel
    @mutex = Mutex.new
    @collection = StreamingItemCollection.new
    @realtime_thread = RealtimeStreamingThread.new(@channel, @collection)
    @realtime_thread.start
    @logged_threads = []
  end

  def add(data)
    @mutex.synchronize do
      start_time = nil
      start_time = data["start_time"].to_i if data["start_time"]
      end_time = nil
      end_time = data["end_time"].to_i if data["end_time"]
      scope = data["scope"]
      items = []
      items_by_topic = {}
      data["items"].each do |item_key|
        item = StreamingItem.new(item_key, start_time, end_time, scope: scope)
        items_by_topic[item.topic] ||= []
        items_by_topic[item.topic] << item
        items << item
      end
      if start_time
        items_by_topic.each do |topic, items|
          items.each {|item| item.thread_id = @thread_id}
          thread = LoggedStreamingThread.new(@thread_id, @channel, @collection, scope: scope)
          thread.start
          @logged_threads << thread
          @thread_id += 1
        end
      end
      @collection.add(items)
    end
  end

  def remove(data)
    @collection.remove(data["items"])
  end

  def kill
    @realtime_thread.stop
    @logged_threads.each do |thread|
      thread.stop
    end
  end
end

# class FakeChannel
#   def transmit(*args)
#     STDOUT.puts args.inspect
#   end
# end

# data = {}
# data["start_time"] = Time.now.to_nsec_from_epoch - 10000000000
# data["end_time"] = Time.now.to_nsec_from_epoch
# data["items"] = ["TLM__INST__HEALTH_STATUS__TEMP1__CONVERTED", "TLM__INST__HEALTH_STATUS__TEMP2__CONVERTED"]
# data["scope"] = 'DEFAULT'
# api = StreamingApi.new("Ryan", FakeChannel.new)
# api.add(data)
# sleep(20)
