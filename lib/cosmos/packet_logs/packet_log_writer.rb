# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'thread'
require 'aws-sdk-s3'
require 'cosmos/config/config_parser'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos-minio:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

module Cosmos

  # Creates a packet log. Can automatically cycle the log based on an elasped
  # time period or when the log file reaches a predefined size.
  class PacketLogWriter

    # @return [String] The filename of the packet log
    attr_reader :filename

    # @return [true/false] Whether logging is enabled
    attr_reader :logging_enabled

    # The cycle time interval. Cycle times are only checked at this level of
    # granularity.
    CYCLE_TIME_INTERVAL = 2

    # @param remote_log_directory [String] The s3 path to store the log files.
    # @param logging_enabled [Boolean] Whether to start with logging enabled
    # @param cycle_time [Integer] The amount of time in seconds before creating
    #   a new log file. This can be combined with cycle_size but is better used
    #   independently.
    # @param cycle_size [Integer] The size in bytes before creating a new log
    #   file. This can be combined with cycle_time but is better used
    #   independently.
    def initialize(
      remote_log_directory,
      label,
      logging_enabled = true,
      cycle_time = nil,
      cycle_size = 1000000000,
      cycle_hour = nil,
      cycle_minute = nil
    )
      @remote_log_directory = remote_log_directory
      @label = label
      @logging_enabled = ConfigParser.handle_true_false(logging_enabled)
      @cycle_time = ConfigParser.handle_nil(cycle_time)
      @cycle_time = Integer(@cycle_time) if @cycle_time
      @cycle_size = ConfigParser.handle_nil(cycle_size)
      @cycle_size = Integer(@cycle_size) if @cycle_size
      @cycle_hour = ConfigParser.handle_nil(cycle_hour)
      @cycle_hour = Integer(@cycle_hour) if @cycle_hour
      @cycle_minute = ConfigParser.handle_nil(cycle_minute)
      @cycle_minute = Integer(@cycle_minute) if @cycle_minute
      @mutex = Mutex.new
      @file = nil
      @file_size = 0
      @filename = nil
      @index_file = nil
      @index_filename = nil
      @index_file = nil
      @index_filename = nil
      @start_time = Time.now.utc
      @cmd_packet_table = {}
      @tlm_packet_table = {}
      @target_dec_entries = []
      @packet_dec_entries = []
      @first_time = nil
      @last_time = nil
      @next_packet_index = 0
      @target_indexes = {}
      @next_target_index = 0
      @cancel_threads = false

      # This is an optimization to avoid creating a new entry object
      # each time we create an entry which we do a LOT!
      @entry = String.new
      @index_entry = String.new

      @cycle_thread = nil
      if @cycle_time or @cycle_hour or @cycle_minute
        @cycle_sleeper = Sleeper.new
        @cycle_thread = Cosmos.safe_thread("Packet log cycle") do
          cycle_thread_body()
        end
      end
    end

    # Write a packet to the log file.
    #
    # If no log file currently exists in the filesystem, a new file will be
    # created.
    #
    # @param entry_type [Symbol] Type of entry to write. Must be one of
    #   :TARGET_DECLARATION, :PACKET_DECLARATION, :RAW_PACKET, :JSON_PACKET
    # @param cmd_or_tlm [Symbol] One of :CMD or :TLM
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param time_nsec_since_epoch [Integer] 64 bit integer nsecs since EPOCH
    # @param stored [Boolean] Whether this data is stored telemetry
    # @param data [String] Binary string of data
    # @param id [Integer] Target ID
    def write(entry_type, cmd_or_tlm, target_name, packet_name, time_nsec_since_epoch, stored, data, id)
      return if !@logging_enabled
      @mutex.synchronize do
        # This check includes logging_enabled again because it might have changed since we acquired the mutex
        if @logging_enabled and (!@file or (@cycle_size and (@file_size + data.length) > @cycle_size))
          start_new_file()
        end
        write_entry(entry_type, cmd_or_tlm, target_name, packet_name, time_nsec_since_epoch, stored, data, id) if @file
      end
    rescue => err
      Logger.instance.error "Error writing #{@filename} : #{err.formatted}"
      Cosmos.handle_critical_exception(err)
    end

    # Starts a new log file by closing the existing log file. New log files are
    # not created until packets are written by {#write} so this does not
    # immediately create a log file on the filesystem.
    def start
      @mutex.synchronize { close_file(false); @logging_enabled = true }
    end

    # Stops all logging and closes the current log file.
    def stop
      @mutex.synchronize { @logging_enabled = false; close_file(false) }
    end

    # Stop all logging, close the current log file, and kill the logging threads.
    def shutdown
      stop()
      if @cycle_thread
        @cycle_sleeper.cancel
        Cosmos.kill_thread(self, @cycle_thread)
        @cycle_thread = nil
      end
      Cosmos.kill_thread(self, @logging_thread)
    end

    def graceful_kill
      @cancel_threads = true
    end

    protected

    def create_unique_filename(extension)
      # Create a filename that doesn't exist
      attempt = nil
      while true
        filename = File.join(Dir.tmpdir, File.build_timestamped_filename([@label, attempt], extension))
        if File.exist?(filename)
          attempt ||= 0
          attempt += 1
        else
          return filename
        end
      end
    end

    # Starting a new log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    # Assumes mutex has already been taken
    def start_new_file
      close_file(false)

      # Start main log file
      @filename = create_unique_filename('.bin'.freeze)
      @file = File.new(@filename, 'wb')
      @file_size = 0
      file_header = build_file_header()
      if file_header
        @file.write(file_header)
        @file_size += file_header.length
      end

      # Start index log file
      @index_filename = create_unique_filename('.idx'.freeze)
      @index_file = File.new(@index_filename, 'wb')
      index_file_header = build_index_file_header()
      @index_file.write(index_file_header) if index_file_header

      @start_time = Time.now.utc
      @cmd_packet_table = {}
      @tlm_packet_table = {}
      @next_packet_index = 0
      @target_indexes = {}
      @target_dec_entries = []
      @packet_dec_entries = []
      @first_time = nil
      @last_time = nil
      Logger.instance.info "Log File Opened : #{@filename}"
      Logger.instance.info "Index Log File Opened : #{@index_filename}"
    rescue => err
      Logger.instance.error "Error opening Tempfile : #{err.formatted}"
      @logging_enabled = false
      Cosmos.handle_critical_exception(err)
    end

    def move_file_to_s3(filename, s3_key)
      Thread.new do
        begin
          rubys3_client = Aws::S3::Client.new

          # Ensure logs bucket exists
          begin
            rubys3_client.head_bucket(bucket: 'logs')
          rescue Aws::S3::Errors::NotFound
            rubys3_client.create_bucket(bucket: 'logs')
          end

          # Write to S3 Bucket
          File.open(filename, 'rb') do |read_file|
            rubys3_client.put_object(bucket: 'logs', key: s3_key, body: read_file)
          end

          Logger.info "logs/#{s3_key} written to S3"

          File.delete(filename)
          Logger.info("local file #{filename} deleted")
        rescue => err
          Logger.error("Error saving log file to bucket: #{filename}\n#{err.formatted}")
        end
      end
    end

    # Closing a log file isn't critical so we just log an error
    def close_file(take_mutex = true)
      @mutex.lock if take_mutex

      begin
        if @file
          begin
            @file.close unless @file.closed?
            Logger.info "Log File Closed : #{@filename}"
            s3_key = File.join(@remote_log_directory, "#{@first_time}__#{@last_time}__#{@label}.bin")
            move_file_to_s3(@filename, s3_key)
          rescue Exception => err
            Logger.instance.error "Error closing #{@filename} : #{err.formatted}"
          end

          @file = nil
          @file_size = 0
          @filename = nil
        end
        if @index_file
          begin
            write_index_file_footer()
            @index_file.close unless @index_file.closed?
            Logger.info "Index Log File Closed : #{@index_filename}"
            s3_key = File.join(@remote_log_directory, "#{@first_time}__#{@last_time}__#{@label}.idx")
            move_file_to_s3(@index_filename, s3_key)
          rescue Exception => err
            Logger.instance.error "Error closing #{@index_filename} : #{err.formatted}"
          end

          @index_file = nil
          @index_filename = nil
        end
      ensure
        @mutex.unlock if take_mutex
      end
    end

    def cycle_thread_body
      while true
        # The check against start_time needs to be mutex protected to prevent a packet coming in between the check
        # and closing the file
        @mutex.synchronize do
          utc_now = Time.now.utc
          if @logging_enabled and
            (
              # Cycle based on total time logging
              (@cycle_time and (Time.now.utc - @start_time) > @cycle_time) or

              # Cycle daily at a specific time
              (@cycle_hour and @cycle_minute and utc_now.hour == @cycle_hour and utc_now.min == @cycle_minute and @start_time.yday != utc_now.yday) or

              # Cycle hourly at a specific time
              (@cycle_minute and not @cycle_hour and utc_now.min == @cycle_minute and @start_time.hour != utc_now.hour)
            )
            close_file(false)
          end
        end
        # Only check whether to cycle at a set interval
        break if @cycle_sleeper.sleep(CYCLE_TIME_INTERVAL)
      end
    end

    def build_file_header
      return "COSMOS5_".freeze
    end

    def build_index_file_header
      return "COSIDX5_".freeze
    end

    COSMOS5_TARGET_DECLARATION_ENTRY_TYPE_MASK = 0x1000
    COSMOS5_PACKET_DECLARATION_ENTRY_TYPE_MASK = 0x2000
    COSMOS5_RAW_PACKET_ENTRY_TYPE_MASK = 0x3000
    COSMOS5_JSON_PACKET_ENTRY_TYPE_MASK = 0x4000
    COSMOS5_CMD_FLAG_MASK = 0x0800
    COSMOS5_STORED_FLAG_MASK = 0x0400
    COSMOS5_ID_FLAG_MASK = 0x0200
    COSMOS5_PRIMARY_FIXED_SIZE = 2
    COSMOS5_TARGET_DECLARATION_SECONDARY_FIXED_SIZE = 1
    COSMOS5_PACKET_DECLARATION_SECONDARY_FIXED_SIZE = 3
    COSMOS5_RAW_PACKET_SECONDARY_FIXED_SIZE = 10
    COSMOS5_JSON_PACKET_SECONDARY_FIXED_SIZE = 10
    COSMOS5_ID_FIXED_SIZE = 32
    COSMOS5_MAX_PACKET_INDEX = 65535
    COSMOS5_MAX_TARGET_INDEX = 65535

    def get_packet_index(cmd_or_tlm, target_name, packet_name)
      if cmd_or_tlm == :CMD
        target_table = @cmd_packet_table[target_name]
      else
        target_table = @tlm_packet_table[target_name]
      end
      if target_table
        packet_index = target_table[packet_name]
        return packet_index if packet_index
      else
        # New packet_table entry needed
        target_table = {}
        if cmd_or_tlm == :CMD
          @cmd_packet_table[target_name] = target_table
        else
          @tlm_packet_table[target_name] = target_table
        end
        id = nil
        target = System.targets[target_name]
        id = target.id if target
        write_entry(:TARGET_DECLARATION, cmd_or_tlm, target_name, packet_name, nil, nil, nil, id)
      end

      # New target_table entry needed
      packet_index = @next_packet_index
      raise "Packet Table Overflow" if packet_index > COSMOS5_MAX_PACKET_INDEX
      target_table[packet_name] = packet_index
      @next_packet_index += 1

      id = nil
      begin
        if cmd_or_tlm == :CMD
          id = System.commands.packet(target_nam, packet_name).config_name
        else
          id = System.telemetry.packet(target_name, packet_name).config_name
        end
      rescue
        # No packet def
      end
      write_entry(:PACKET_DECLARATION, cmd_or_tlm, target_name, packet_name, nil, nil, nil, id)
      return packet_index
    end

    def write_entry(entry_type, cmd_or_tlm, target_name, packet_name, time_nsec_since_epoch, stored, data, id)
      length = COSMOS5_PRIMARY_FIXED_SIZE
      flags = 0
      flags |= COSMOS5_STORED_FLAG_MASK if stored
      flags |= COSMOS5_ID_FLAG_MASK if id
      case entry_type
      when :TARGET_DECLARATION
        target_index = @next_target_index
        @target_indexes[target_name] = target_index
        @next_target_index += 1
        raise "Target Index Overflow" if target_index > COSMOS5_MAX_TARGET_INDEX
        flags |= COSMOS5_TARGET_DECLARATION_ENTRY_TYPE_MASK
        length += COSMOS5_TARGET_DECLARATION_SECONDARY_FIXED_SIZE + target_name.length
        length += COSMOS5_ID_FIXED_SIZE if id
        @entry.clear
        @entry << [length, flags, target_name.length].pack('NnC'.freeze) << target_name
        @entry << [id].pack('H*') if id
        @target_dec_entries << @entry.dup
      when :PACKET_DECLARATION
        target_index = @target_indexes[target_name]
        flags |= COSMOS5_PACKET_DECLARATION_ENTRY_TYPE_MASK
        length += COSMOS5_PACKET_DECLARATION_SECONDARY_FIXED_SIZE + packet_name.length
        length += COSMOS5_ID_FIXED_SIZE if id
        @entry.clear
        @entry << [length, flags, target_index, packet_name.length].pack('NnnC'.freeze) << packet_name
        @entry << [id].pack('H*') if id
        @packet_dec_entries << @entry.dup
      when :RAW_PACKET, :JSON_PACKET
        target_name = 'UNKNOWN'.freeze unless target_name
        packet_name = 'UNKNOWN'.freeze unless packet_name
        packet_index = get_packet_index(cmd_or_tlm, target_name, packet_name)
        if entry_type == :RAW_PACKET
          flags |= COSMOS5_RAW_PACKET_ENTRY_TYPE_MASK
        else
          flags |= COSMOS5_JSON_PACKET_ENTRY_TYPE_MASK
        end
        flags |= COSMOS5_CMD_FLAG_MASK if cmd_or_tlm == :CMD
        length += COSMOS5_RAW_PACKET_SECONDARY_FIXED_SIZE + data.length
        @entry.clear
        @index_entry.clear
        @index_entry << [length, flags, packet_index, time_nsec_since_epoch].pack('NnnQ>'.freeze)
        @entry << @index_entry << data
        @index_entry << [@file_size].pack('Q>')
        @index_file.write(@index_entry)
        @first_time = time_nsec_since_epoch if !@first_time or time_nsec_since_epoch < @first_time
        @last_time = time_nsec_since_epoch if !@last_time or time_nsec_since_epoch > @last_time
      else
        raise "Unknown entry_type: #{entry_type}"
      end
      @file.write(@entry)
      @file_size += @entry.length
    end

    def write_index_file_footer
      footer_length = 4 # Includes length of length field at end
      @index_file.write([@target_dec_entries.length].pack('n'))
      footer_length += 2
      @target_dec_entries.each do |target_dec_entry|
        @index_file.write(target_dec_entry)
        footer_length += target_dec_entry.length
      end
      @index_file.write([@packet_dec_entries.length].pack('n'))
      footer_length += 2
      @packet_dec_entries.each do |packet_dec_entry|
        @index_file.write(packet_dec_entry)
        footer_length += packet_dec_entry.length
      end
      @index_file.write([footer_length].pack('N'))
    end

  end # class PacketLogWriter

end # module Cosmos
