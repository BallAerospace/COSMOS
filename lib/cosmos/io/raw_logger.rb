# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'thread'
require 'socket' # For gethostname
require 'cosmos/config/config_parser'

module Cosmos
  # Creates a log file of raw data for either reads or writes. Can automatically
  # cycle the log based on when the log file reaches a predefined size.
  class RawLogger

    # @return [String] The filename of the log
    attr_reader :filename

    # @return [Queue] Queue for asynchronous logging
    attr_reader :queue

    # @return [Boolean] Is logging enabled?
    attr_reader :logging_enabled

    # @return [String] Original name passed to raw logger
    attr_reader :orig_name

    # The allowable log types
    LOG_TYPES = [:READ, :WRITE]

    # The cycle time interval. Cycle times are only checked at this level of
    # granularity.
    CYCLE_TIME_INTERVAL = 60

    # @param log_name [String] The name of the raw logger.  Typically matches the
    #    name of the corresponding interface
    # @param log_type [Symbol] The type of log to create. Must be :READ
    #   or :WRITE.
    # @param log_directory [String] The directory to store the log files.
    # @param logging_enabled [Boolean] Whether to enable raw logging
    # @param cycle_size [Integer] The size in bytes before creating a new log file.
    def initialize(
      log_name,
      log_type,
      log_directory,
      logging_enabled = false,
      cycle_size = 2000000000
    )
      raise "log_type must be :READ or :WRITE" unless LOG_TYPES.include? log_type
      @log_type = log_type
      @orig_name = log_name
      @log_name = (log_name.to_s.downcase + '_raw_' + @log_type.to_s.downcase + '_' + self.object_id.to_s).freeze
      @log_directory = log_directory
      @cycle_size = ConfigParser.handle_nil(cycle_size)
      @cycle_size = Integer(@cycle_size) if @cycle_size
      @mutex = Mutex.new
      @file = nil
      @filename = nil
      @start_time = Time.now.sys
      @logging_enabled = ConfigParser.handle_true_false(logging_enabled)
    end

    # Set the raw logger name
    # @param log_name [String] new name
    def name=(log_name)
      @orig_name = log_name
      @log_name = (log_name.to_s.downcase + '_raw_' + @log_type.to_s.downcase + '_' + self.object_id.to_s).freeze
    end

    # Write data to the log file.
    #
    # If no log file currently exists in the filesystem, a new file will be
    # created.
    #
    # Writing a log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    #
    # @param data [String] The data to write to the log file
    def write(data)
      if @logging_enabled
        return if !data or data.length <= 0
        need_new_file = false
        @mutex.synchronize do
          if !@file or (@cycle_size and (@file.stat.size + data.length) > @cycle_size)
            need_new_file = true
          end
        end
        start_new_file() if need_new_file
        @mutex.synchronize { @file.write(data) if @file }
      end
    rescue => err
      Logger.instance.error "Error writing #{@filename} : #{err.formatted}"
      Cosmos.handle_critical_exception(err)
    end

    # Starts a new log file by closing the existing log file. New log files are
    # not created until data is written by {#write} so this does not
    # immediately create a log file on the filesystem.
    def start
      close_file() unless ((Time.now.sys - @start_time) < 1.0) # Prevent close/open too fast
      @mutex.synchronize { @logging_enabled = true }
    end

    # Stops all logging and closes the current log file.
    def stop
      @mutex.synchronize { @logging_enabled = false }
      close_file()
    end

    # Create a clone of this object with a new name
    def clone
      raw_logger = super()
      raw_logger.name = raw_logger.orig_name
      raw_logger
    end

    protected

    # Starting a new log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    def start_new_file
      close_file()
      @mutex.synchronize do
        @filename = File.join(@log_directory, File.build_timestamped_filename([@log_name], '.bin'))
        @file = File.new(@filename, 'wb')
        @start_time = Time.now.sys
        Logger.instance.info "Raw Log File Opened : #{@filename}"
      end
    rescue => err
      Logger.instance.error "Error opening #{@filename} : #{err.formatted}"
      @logging_enabled = false
      Cosmos.handle_critical_exception(err)
    end

    # Closing a log file isn't critical so we just log an error
    def close_file
      @mutex.synchronize do
        if @file
          begin
            @file.close unless @file.closed?
            File.chmod(0444, @file.path) # Make file read only
            Logger.instance.info "Raw Log File Closed : #{@filename}"
          rescue => err
            Logger.instance.error "Error closing #{@filename} : #{err.formatted}"
          end

          @file = nil
          @filename = nil
        end
      end
    end
  end
end
