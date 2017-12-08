# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Handles logic for the Replay mode
  class ReplayBackend

    # The number of bytes to print when an UNKNOWN packet is received
    UNKNOWN_BYTES_TO_PRINT = 36

    attr_accessor :log_directory
    attr_accessor :log_filename
    attr_accessor :packet_log_reader
    attr_accessor :config_change_callback

    # @param cmd_tlm_server_config [CmdTlmServerConfig]
    def initialize(cmd_tlm_server_config)
      @config = cmd_tlm_server_config
      reset()
      @config_change_callback = nil
    end

    # Reset internal state
    def reset
      @cancel = false
      @playback_delay = 0.0
      @default_packet_log_reader = System.default_packet_log_reader.new(*System.default_packet_log_reader_params)
      @packet_log_reader = @default_packet_log_reader
      @log_directory = System.paths['LOGS']
      @log_directory << '/' unless @log_directory[-1..-1] == '\\' or @log_directory[-1..-1] == '/'
      @log_filename = nil
      @playing = false
      @playback_sleeper = nil
      @thread = nil
      @playback_index = 0
      @playback_max_index = 0
      @packet_offsets = []
      @progress = 0
      @status = ''
      @start_time = ''
      @current_time = ''
      @end_time = ''
    end

    # Select and start analyzing a file for replay
    #
    # filename [String] filename relative to output logs folder or absolute filename
    def select_file(filename, packet_log_reader = 'DEFAULT')
      stop()
      Cosmos.kill_thread(self, @thread)
      @thread = Thread.new do
        begin
          stop()
          if String === packet_log_reader
            if packet_log_reader == 'DEFAULT'
              @packet_log_reader = @default_packet_log_reader
            else
              packet_log_reader = Cosmos.require_class(packet_log_reader)
              @packet_log_reader = packet_log_reader_class.new
            end
          elsif !packet_log_reader.nil?
            # Instantiated object
            @packet_log_reader = packet_log_reader
          end # Else use existing

          @log_filename = filename
          @log_directory = File.dirname(@log_filename)
          @log_directory << '/' unless @log_directory[-1..-1] == '\\'

          System.telemetry.reset
          @cancel = false
          @progress = 0
          @status = "Analyzing: #{@progress}%"
          start_config_name = System.configuration_name
          Cosmos.check_log_configuration(@packet_log_reader, @log_filename)
          if System.configuration_name != start_config_name
            @config_change_callback.call() if @config_change_callback
          end
          @packet_offsets = @packet_log_reader.packet_offsets(@log_filename, lambda {|percentage|
            progress_int = (percentage * 100).to_i
            if @progress != progress_int
              @progress = progress_int
              @status = "Analyzing: #{@progress}%"
            end
            @cancel
          })
          @playback_index = 0
          @playback_max_index = @packet_offsets.length
          @packet_log_reader.open(@log_filename)

          if @cancel
            @packet_log_reader.close
            @log_filename = ''
            @packet_offsets = []
            @playback_index = 0
            @start_time = ''
            @current_time = ''
            @end_time = ''
          else
            packet = read_at_index(@packet_offsets.length - 1, :FORWARD)
            @end_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
            packet = read_at_index(0, :FORWARD)
            @start_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
          end
        rescue Exception => error
          Logger.error "Error in Analysis Thread\n#{error.formatted}"
        ensure
          @status = 'Stopped'
          @playing = false
          @playback_sleeper = nil
          @thread = nil
        end
      end
    end

    # Get current replay status
    #
    # @return [status, playback_delay, filename, file_start, file_current, file_end, file_index, file_max_index]
    def status
      [@status,
        @playback_delay,
        @log_filename.to_s,
        @start_time,
        @current_time,
        @end_time,
        @playback_index,
        @playback_max_index]
    end

    # Set the replay delay
    #
    # @param delay [Float] delay between packets in seconds 0.0 to 1.0, nil = No Delay, -1.0 = REALTIME
    def set_playback_delay(delay)
      if delay
        delay = delay.to_f
        if delay <= 0.0
          @playback_delay = 0.0
        elsif delay > 1.0
          @playback_delay = 1.0
        else
          @playback_delay = delay
        end
      else
        @playback_delay = nil
      end
    end

    # Replay start playing forward
    def play
      if @log_filename and !@thread
        @playback_index = 1 if @playback_index < 0
        start_playback(:FORWARD)
      else
        stop()
      end
    end

    # Replay start playing backward
    def reverse_play
      if @log_filename and !@thread
        @playback_index = @packet_offsets.length - 2 if @playback_index >= @packet_offsets.length
        start_playback(:BACKWARD)
      else
        stop()
      end
    end

    # Replay stop
    def stop
      @cancel = true
      @playing = false
      @playback_sleeper.cancel if @playback_sleeper
    end

    # Replay step forward one packet
    def step_forward
      if @log_filename and !@thread
        @playback_index = 1 if @playback_index < 0
        read_at_index(@playback_index, :FORWARD)
      else
        stop()
      end
    end

    # Replay step backward one packet
    def step_back
      if @log_filename and !@thread
        @playback_index = @packet_offsets.length - 2 if @playback_index >= @packet_offsets.length
        read_at_index(@playback_index, :BACKWARD)
      else
        stop()
      end
    end

    # Replay move to start of file
    def move_start
      if @log_filename and !@thread
        packet = read_at_index(0, :FORWARD)
        @start_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
      else
        stop()
      end
    end

    # Replay move to end of file
    def move_end
      if @log_filename and !@thread
        packet = read_at_index(@packet_offsets.length - 1, :FORWARD)
        @end_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
      else
        stop()
      end
    end

    # Replay move to index
    #
    # @param index [Integer] packet index into file
    def move_index(index)
      if @log_filename and !@thread
        read_at_index(index, :FORWARD)
      end
    end

    def shutdown
      stop()
      Cosmos.kill_thread(self, @thread)
      reset()
    end

    # Gracefully kill threads
    def graceful_kill
      stop()
    end

    private

    def start_playback(direction)
      @thread = Thread.new do
        @playback_sleeper = Sleeper.new
        error = nil
        begin
          @playing = true
          @status = 'Playing'

          previous_packet = nil
          while (@playing)
            if @playback_delay != 0.0
              packet_start = Time.now.sys
              packet = read_at_index(@playback_index, direction)
              break unless packet
              delay_time = 0.0
              if @playback_delay
                # Fixed Time Delay
                delay_time = @playback_delay - (Time.now.sys - packet_start)
              elsif previous_packet and packet.received_time and previous_packet.received_time
                # Realtime
                if direction == :FORWARD
                  delay_time = packet.received_time - previous_packet.received_time - (Time.now.sys - packet_start)
                else
                  delay_time = previous_packet.received_time - packet.received_time - (Time.now.sys - packet_start)
                end
              end
              if delay_time > 0.0
                break if @playback_sleeper.sleep(delay_time)
              end
              previous_packet = packet
            else
              # No Delay
              packet = read_at_index(@playback_index, direction)
              break unless packet
              previous_packet = packet
            end
          end
        rescue Exception => error
          Logger.error "Error in Playback Thread\n#{error.formatted}"
        ensure
          @status = 'Stopped'
          @playing = false
          @playback_sleeper = nil
          @thread = nil
        end
      end
    end

    def read_at_index(index, direction)
      packet_offset = nil
      packet_offset = @packet_offsets[index] if index >= 0
      if packet_offset
        # Read the packet
        packet = @packet_log_reader.read_at_offset(packet_offset, false)
        handle_packet(packet)

        # Adjust index for next read
        if direction == :FORWARD
          @playback_index = index + 1
        else
          @playback_index = index - 1
        end
        @current_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time

        return packet
      else
        return nil
      end
    end

    def handle_packet(packet)
      # For replay we will try our best here but not crash on errors
      begin
        interface = nil

        # Identify and update packet
        if packet.identified?
          # Preidentifed packet - place it into the current value table
          identified_packet = System.telemetry.update!(packet.target_name,
                                                        packet.packet_name,
                                                        packet.buffer)
        else
          # Packet needs to be identified
          identified_packet = System.telemetry.identify!(packet.buffer)
        end

        if identified_packet and packet.target_name != 'UNKNOWN'
          identified_packet.received_time = packet.received_time
          packet = identified_packet
          target = System.targets[packet.target_name.upcase]
          interface = target.interface if target
        else
          unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
          unknown_packet.received_time = packet.received_time
          packet = unknown_packet
          data_length = packet.length
          string = "Unknown #{data_length} byte packet starting: "
          num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
          data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
          data_to_print.each_byte do |byte|
            string << sprintf("%02X", byte)
          end
          time_string = ''
          time_string = packet.received_time.formatted << '  ' if packet.received_time
          puts "#{time_string}ERROR:  #{string}"
        end

        target = System.targets[packet.target_name]
        target.tlm_cnt += 1 if target
        packet.received_count += 1
        packet.check_limits(System.limits_set)
        CmdTlmServer.instance.post_packet(packet)

        # Write to routers
        if interface
          interface.routers.each do |router|
            begin
              router.write(packet) if router.write_allowed? and router.connected?
            rescue => err
              Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
            end
          end
        end
      rescue Exception => err
        Logger.error "Problem handling packet #{packet.target_name} #{packet.packet_name} - #{err.class}:#{err.message}"
      end
    end

  end # class ReplayBackend

end # module Cosmos
