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

require 'thread'
require 'cosmos/config/config_parser'
require 'cosmos/utilities/store'
require 'cosmos/utilities/s3'

module Cosmos
  # Creates a log. Can automatically cycle the log based on an elasped
  # time period or when the log file reaches a predefined size.
  class LogWriter
    # @return [String] The filename of the packet log
    attr_reader :filename

    # @return [true/false] Whether logging is enabled
    attr_reader :logging_enabled

    # The cycle time interval. Cycle times are only checked at this level of
    # granularity.
    CYCLE_TIME_INTERVAL = 2

    # @param remote_log_directory [String] The s3 path to store the log files
    # @param logging_enabled [Boolean] Whether to start with logging enabled
    # @param cycle_time [Integer] The amount of time in seconds before creating
    #   a new log file. This can be combined with cycle_size but is better used
    #   independently.
    # @param cycle_size [Integer] The size in bytes before creating a new log
    #   file. This can be combined with cycle_time but is better used
    #   independently.
    # @param cycle_hour [Integer] The time at which to cycle the log. Combined with
    #   cycle_minute to cycle the log daily at the specified time. If nil, the log
    #   will be cycled hourly at the specified cycle_minute.
    # @param cycle_minute [Integer] The time at which to cycle the log. See cycle_hour
    #   for more information.
    # @param redis_topic [String] The key of the Redis stream to trim when files are
    #   moved to S3
    def initialize(
      remote_log_directory,
      logging_enabled = true,
      cycle_time = nil,
      cycle_size = 1000000000,
      cycle_hour = nil,
      cycle_minute = nil,
      redis_topic: nil
    )
      @remote_log_directory = remote_log_directory
      @logging_enabled = ConfigParser.handle_true_false(logging_enabled)
      @cycle_time = ConfigParser.handle_nil(cycle_time)
      if @cycle_time
        @cycle_time = Integer(@cycle_time)
        raise "cycle_time must be >= #{CYCLE_TIME_INTERVAL}" if @cycle_time < CYCLE_TIME_INTERVAL
      end
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
      @start_time = Time.now.utc
      @first_time = nil
      @last_time = nil
      @cancel_threads = false
      @last_offset = nil
      @previous_file_redis_offset = nil
      @redis_topic = redis_topic

      # This is an optimization to avoid creating a new entry object
      # each time we create an entry which we do a LOT!
      @entry = String.new

      @cycle_thread = nil
      if @cycle_time or @cycle_hour or @cycle_minute
        @cycle_sleeper = Sleeper.new
        @cycle_thread = Cosmos.safe_thread("Log cycle") do
          cycle_thread_body()
        end
      end
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
    end

    def graceful_kill
      @cancel_threads = true
    end

    protected

    def create_unique_filename(ext = extension)
      # Create a filename that doesn't exist
      attempt = nil
      while true
        filename_parts = [attempt]
        filename_parts.unshift @label if @label
        filename = File.join(Dir.tmpdir, File.build_timestamped_filename([@label, attempt], ext))
        if File.exist?(filename)
          attempt ||= 0
          attempt += 1
        else
          return filename
        end
      end
    end

    def cycle_thread_body
      while true
        # The check against start_time needs to be mutex protected to prevent a packet coming in between the check
        # and closing the file
        @mutex.synchronize do
          utc_now = Time.now.utc
          # Logger.debug("start:#{@start_time.to_f} now:#{utc_now.to_f} cycle:#{@cycle_time} new:#{(utc_now - @start_time) > @cycle_time}")
          if @logging_enabled and
             (
               # Cycle based on total time logging
               (@cycle_time and (utc_now - @start_time) > @cycle_time) or

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

    # Starting a new log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    # Assumes mutex has already been taken
    def start_new_file
      close_file(false)

      # Start log file
      @filename = create_unique_filename()
      @file = File.new(@filename, 'wb')
      @file_size = 0

      @start_time = Time.now.utc
      @first_time = nil
      @last_time = nil
      Logger.instance.info "Log File Opened : #{@filename}"
    rescue => err
      Logger.instance.error "Error starting new log file: #{err.formatted}"
      @logging_enabled = false
      Cosmos.handle_critical_exception(err)
    end

    def prepare_write(time_nsec_since_epoch, data_length, redis_offset)
      # This check includes logging_enabled again because it might have changed since we acquired the mutex
      if @logging_enabled and (!@file or (@cycle_size and (@file_size + data_length) > @cycle_size))
        start_new_file()
      end
      @last_offset = redis_offset # This is needed for the redis offset marker entry at the end of the log file
    end

    # Closing a log file isn't critical so we just log an error. NOTE: This also trims the Redis stream
    # to keep a full file's worth of data in the stream. This is what prevents continuous stream growth.
    def close_file(take_mutex = true)
      @mutex.lock if take_mutex
      begin
        if @file
          begin
            @file.close unless @file.closed?
            Logger.info "Log File Closed : #{@filename}"
            date = first_timestamp[0..7] # YYYYMMDD
            s3_key = File.join(@remote_log_directory, date, s3_filename)
            S3Utilities.move_log_file_to_s3(@filename, s3_key)
            # Now that the file is in S3, trim the Redis stream up until the previous file.
            # This keeps one file worth of data in Redis as a safety buffer
            Cosmos::Store.trim_topic(@redis_topic, @previous_file_redis_offset) if @redis_topic and @previous_file_redis_offset
            @previous_file_redis_offset = @last_offset
          rescue Exception => err
            Logger.instance.error "Error closing #{@filename} : #{err.formatted}"
          end

          @file = nil
          @file_size = 0
          @filename = nil
        end
      ensure
        @mutex.unlock if take_mutex
      end
    end

    def s3_filename
      "#{first_timestamp}__#{last_timestamp}" + extension
    end

    def extension
      '.log'.freeze
    end

    def first_timestamp
      Time.from_nsec_from_epoch(@first_time).to_timestamp # "YYYYMMDDHHmmSSNNNNNNNNN"
    end

    def last_timestamp
      Time.from_nsec_from_epoch(@last_time).to_timestamp # "YYYYMMDDHHmmSSNNNNNNNNN"
    end
  end
end
