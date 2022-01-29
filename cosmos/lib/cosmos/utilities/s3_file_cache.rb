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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'fileutils'
require 'cosmos'
require 'cosmos/utilities/s3'

class S3File
  attr_reader :s3_path
  attr_reader :local_path
  attr_reader :reservation_count
  attr_reader :size
  attr_reader :error
  attr_accessor :priority

  def initialize(s3_path, size = 0, priority = 0)
    @rubys3_client = Aws::S3::Client.new
    begin
      @rubys3_client.head_bucket(bucket: 'logs')
    rescue Aws::S3::Errors::NotFound
      @rubys3_client.create_bucket(bucket: 'logs')
    end

    @s3_path = s3_path
    @local_path = nil
    @reservation_count = 0
    @size = size
    @priority = priority
    @error = nil
    @mutex = Mutex.new
  end

  def retrieve
    local_path = "#{S3FileCache.instance.cache_dir}/#{File.basename(@s3_path)}"
    Cosmos::Logger.info "Retrieving #{@s3_path} from logs bucket"
    @rubys3_client.get_object(bucket: "logs", key: @s3_path, response_target: local_path)
    if File.exist?(local_path)
      @size = File.size(local_path)
      @local_path = local_path
    end
  rescue => err
    @error = err
    Cosmos::Logger.error "Failed to retrieve #{@s3_path}\n#{err.formatted}"
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

class S3FileCollection
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
      file = S3File.new(s3_path, size, priority)
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

class S3FileCache
  MAX_DISK_USAGE = 20_000_000_000 # 20 GB
  TIMESTAMP_FORMAT = "%Y%m%d%H%M%S%N" # TODO: get from different class?

  attr_reader :cache_dir

  @@instance = nil
  @@mutex = Mutex.new

  def self.instance
    return @@instance if @@instance
    @@mutex.synchronize do
      @@instance ||= S3FileCache.new
    end
    @@instance
  end

  def initialize(name = 'default', max_disk_usage = MAX_DISK_USAGE)
    @max_disk_usage = max_disk_usage

    @rubys3_client = Aws::S3::Client.new
    begin
      @rubys3_client.head_bucket(bucket: 'logs')
    rescue Aws::S3::Errors::NotFound
      @rubys3_client.create_bucket(bucket: 'logs')
    end

    # Create local file cache location
    @cache_dir = File.join(Dir.tmpdir, 'cosmos', 'file_cache', name)
    FileUtils.mkdir_p(@cache_dir)

    # Clear out local file cache
    FileUtils.rm_f Dir.glob("#{@cache_dir}/*")

    @cached_files = S3FileCollection.new

    @thread = Thread.new do
      while true
        file = @cached_files.get_next_to_retrieve
        # Cosmos::Logger.debug "Next file: #{file}"
        if file and (file.size + @cached_files.current_disk_usage()) <= @max_disk_usage
          file.retrieve
        else
          sleep(1)
        end
      end
    rescue => err
      Cosmos::Logger.error "S3FileCache thread unexpectedly died\n#{err.formatted}"
    end
  end

  def reserve_file(cmd_or_tlm, target_name, packet_name, start_time_nsec, end_time_nsec, type = :DECOM, timeout = 60, scope:)
    # Cosmos::Logger.debug "reserve_file #{cmd_or_tlm}:#{target_name}:#{packet_name} start:#{start_time_nsec / 1_000_000_000} end:#{end_time_nsec / 1_000_000_000} type:#{type} timeout:#{timeout}"
    # Get List of Files from S3
    total_resp = []
    token = nil
    dates = []
    cur_date = Time.at(start_time_nsec / Time::NSEC_PER_SECOND).beginning_of_day
    end_date = Time.at(end_time_nsec / Time::NSEC_PER_SECOND).beginning_of_day
    cur_date -= 1.day # start looking in the folder for the day before because log files can span across midnight
    while cur_date <= end_date
      dates << cur_date.strftime("%Y%m%d")
      cur_date += 1.day
    end
    prefixes = []
    dates.each do |date|
      while true
        prefixes << "#{scope}/#{type.to_s.downcase}_logs/#{cmd_or_tlm.to_s.downcase}/#{target_name}/#{packet_name}/#{date}"
        resp = @rubys3_client.list_objects_v2({
          bucket: "logs",
          max_keys: 1000,
          prefix: prefixes[-1],
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
    else
      Cosmos::Logger.info "No files found for #{prefixes}"
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
    file_start_timestamp, file_end_timestamp, other = basename.split("__")
    file_start_time_nsec = DateTime.strptime(file_start_timestamp, TIMESTAMP_FORMAT).to_f * Time::NSEC_PER_SECOND
    file_end_time_nsec = DateTime.strptime(file_end_timestamp, TIMESTAMP_FORMAT).to_f * Time::NSEC_PER_SECOND
    if (start_time_nsec < file_end_time_nsec) and (end_time_nsec >= file_start_time_nsec)
      return true
    else
      return false
    end
  end
end
