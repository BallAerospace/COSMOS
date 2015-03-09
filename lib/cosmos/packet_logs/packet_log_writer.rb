# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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

  # Creates a packet log of either commands or telemetry. Can automatically
  # cycle the log based on an elasped time period or when the log file reaches
  # a predefined size.
  class PacketLogWriter

    # @return [String] The filename of the packet log
    attr_reader :filename

    # @return [true/false] Whether logging is enabled
    attr_reader :logging_enabled

    # @return [Queue] Queue for asynchronous logging
    attr_reader :queue

    # The allowable log types
    LOG_TYPES = [:CMD, :TLM]

    # The cycle time interval. Cycle times are only checked at this level of
    # granularity.
    CYCLE_TIME_INTERVAL = 2

    # @param log_type [Symbol] The type of packet log to create. Must be :CMD
    #   or :TLM.
    # @param log_name [String|nil] Identifier to put in the log file name. This
    #   will be prepended with a date / time stamp and appended by the
    #   log_type. Thus passing 'test' for a :CMD log will result in a filename
    #   of 'YYYY_MM_DD_HH_MM_SS_testcmd.bin'. Pass nil to ignore this
    #   parameter.
    # @param logging_enabled [Boolean] Whether to start with logging enabled
    # @param cycle_time [Integer] The amount of time in seconds before creating
    #   a new log file. This can be combined with cycle_size but is better used
    #   independently.
    # @param cycle_size [Integer] The size in bytes before creating a new log
    #   file. This can be combined with cycle_time but is better used
    #   independently.
    # @param log_directory [String] The directory to store the log files.
    #   Passing nil will use the system default 'LOGS' directory.
    # @param asynchronous [Boolean] Whether to spawn a new thread to write
    #   packets to the log rather than writing the packets in the current
    #   thread context.  Note that this is (alot) slower overall but may reduce
    #   interface receive latency
    def initialize(
      log_type,
      log_name = nil,
      logging_enabled = true,
      cycle_time = nil,
      cycle_size = 2000000000,
      log_directory = nil,
      asynchronous = false
    )
      raise "log_type must be :CMD or :TLM" unless LOG_TYPES.include? log_type
      @log_type = log_type
      if ConfigParser.handle_nil(log_name)
        @log_name = (log_name.to_s + @log_type.to_s.downcase).freeze
      else
        @log_name = @log_type.to_s.downcase.freeze
      end
      @logging_enabled = ConfigParser.handle_true_false(logging_enabled)
      @cycle_time = ConfigParser.handle_nil(cycle_time)
      @cycle_time = Integer(@cycle_time) if @cycle_time
      @cycle_size = ConfigParser.handle_nil(cycle_size)
      @cycle_size = Integer(@cycle_size) if @cycle_size
      if ConfigParser.handle_nil(log_directory)
        @log_directory = log_directory
      else
        @log_directory = System.instance.paths['LOGS']
      end
      @asynchronous = ConfigParser.handle_true_false(asynchronous)
      @queue = Queue.new
      @mutex = Mutex.new
      @file = nil
      @file_size = 0
      @filename = nil
      @label = nil
      @entry_header = String.new
      @start_time = Time.now

      @cancel_threads = false
      @logging_thread = nil
      if @asynchronous
        @logging_thread = Cosmos.safe_thread("Packet log") do
          logging_thread_body()
        end
      end

      @cycle_thread = nil
      if @cycle_time
        @cycle_sleeper = Sleeper.new
        @cycle_thread = Cosmos.safe_thread("Packet log cycle") do
          cycle_thread_body()
        end
      end
    end

    # Write a packet to the log file. If the log file was created with
    # asynchronous = true the packet will be put on a queue and written by the
    # log writer thread. Otherwise the packet will be written in the caller's
    # thread context.
    #
    # If no log file currently exists in the filesystem, a new file will be
    # created.
    #
    # @param packet [Packet] The packet to write to the log file
    def write(packet)
      if @asynchronous
        @queue << packet.clone
      else
        write_packet(packet)
      end
    end

    # Starts a new log file by closing the existing log file. New log files are
    # not created until packets are written by {#write} so this does not
    # immediately create a log file on the filesystem.
    #
    # @param label [String] Label to append to the logfile name. This label
    #   will be placed after the cmd or tlm in the filename. For example, if
    #   'test' is given to a command log file, the filename will be
    #   'YYYY_MM_DD_HH_MM_SS_cmd_test.bin'.
    def start(label = nil)
      new_label = label.to_s.strip
      if new_label.length == 0
        @label = nil
      elsif new_label =~ /^[a-zA-Z0-9]*$/
        @label = new_label
      else
        # Invalid label - Clear out existing
        @label = nil
      end

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
      @queue << nil
    end

    protected

    # Starting a new log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    # Assumes mutex has already been taken
    def start_new_file
      close_file(false)
      Cosmos.set_working_dir do
        # Create a filename that doesn't exist
        attempt = nil
        while true
          @filename = File.join(@log_directory, File.build_timestamped_filename([@log_name, @label, attempt], '.bin'))
          if File.exist?(@filename)
            attempt ||= 0
            attempt += 1
          else
            break
          end
        end

        @file = File.new(@filename, 'wb')
        @file_size = 0
      end
      file_header = build_file_header()
      if file_header
        @file.write(file_header)
        @file_size += file_header.length
      end
      @start_time = Time.now
      Logger.instance.info "Log File Opened : #{@filename}"
      start_new_file_hook()
    rescue => err
      Logger.instance.error "Error opening #{@filename} : #{err.formatted}"
      @logging_enabled = false
      Cosmos.handle_critical_exception(err)
    end

    # Hook after writing the file header in start_new_file
    # Mutex is held during this hook
    def start_new_file_hook
      # Default do nothing
    end

    # Closing a log file isn't critical so we just log an error
    def close_file(take_mutex = true)
      @mutex.lock if take_mutex

      begin
        if @file
          begin
            @file.close unless @file.closed?
            Cosmos.set_working_dir do
              File.chmod(0444, @file.path) # Make file read only
            end
            Logger.instance.info "Log File Closed : #{@filename}"
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

    # Writing a log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    def write_packet(packet, take_mutex = true)
      return if !packet or !@logging_enabled
      @mutex.lock if take_mutex
      begin
        # This check includes logging_enabled again because it might have changed since we acquired the mutex
        if @logging_enabled and (!@file or (@cycle_size and (@file_size + packet.length) > @cycle_size))
          start_new_file()
        end
        if @file
          @entry_header = build_entry_header(packet) # populate @entry_header
          if @entry_header
            @file.write(@entry_header)
            @file_size += @entry_header.length
          end
          buffer = packet.buffer
          @file.write(buffer)
          @file_size += buffer.length
        end
      ensure
        @mutex.unlock if take_mutex
      end
    rescue => err
      Logger.instance.error "Error writing #{@filename} : #{err.formatted}"
      Cosmos.handle_critical_exception(err)
    end

    def logging_thread_body
      while true
        begin
          packet = @queue.pop
          return if @cancel_threads
        rescue ThreadError
          # This can happen when the thread is killed
          return
        end
        write_packet(packet)
      end
    end

    def cycle_thread_body
      while true
        # The check against start_time needs to be mutex protected to prevent a packet coming in between the check
        # and closing the file
        @mutex.synchronize do
          if @logging_enabled and @cycle_time and (Time.now - @start_time) > @cycle_time
            close_file(false)
          end
        end
        # Only check whether to cycle at a set interval
        break if @cycle_sleeper.sleep(CYCLE_TIME_INTERVAL)
      end
    end

    def build_file_header
      hostname = Socket.gethostname.to_s
      file_header = "COSMOS2_#{@log_type}_#{System.configuration_name}_"
      file_header << hostname.ljust(83)
      return file_header
    end

    def build_entry_header(packet)
      received_time = packet.received_time
      received_time = Time.now unless received_time
      # This is an optimization to avoid creating a new entry_header object
      # each time we create an entry_header which we do a LOT!
      @entry_header.clear
      @entry_header << [received_time.tv_sec].pack('N'.freeze)
      @entry_header << [received_time.tv_usec].pack('N'.freeze)
      target_name = packet.target_name
      target_name = 'UNKNOWN'.freeze unless target_name
      @entry_header << target_name.length
      @entry_header << target_name
      packet_name = packet.packet_name
      packet_name = 'UNKNOWN'.freeze unless packet_name
      @entry_header << packet_name.length
      @entry_header << packet_name
      @entry_header << [packet.length].pack('N'.freeze)
      return @entry_header
    end

  end # class PacketLogWriter

end # module Cosmos
