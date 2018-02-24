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
    SLIDER_GRANULARITY = 10000

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
      @first = true
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
      @start_time_object = nil
      @current_time = ''
      @current_time_object = nil
      @end_time = ''
      @end_time_object = nil
      @mode = :stream
      @interface = Cosmos::TcpipClientInterface.new(
        Cosmos::System.connect_hosts['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        10, 30, 'PREIDENTIFIED')
    end

    # Select and start analyzing a file for replay
    #
    # filename [String] filename relative to output logs folder or absolute filename
    def select_file(filename, packet_log_reader = 'DEFAULT')
      stop()
      Cosmos.kill_thread(self, @thread)
      @mode = :file
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
            @log_filename = nil
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

    # Setup streaming with the given arguments
    #
    # start_time [Time] Time at which stream should begin at
    # end_time [Time] Time at which stream should stop
    def select_stream(start_time, end_time, meta_filters = [])
      stop()
      Cosmos.kill_thread(self, @thread)
      @thread = nil
      @mode = :stream
      @log_filename = nil
      @log_directory = System.paths['LOGS']
      @log_directory << '/' unless @log_directory[-1..-1] == '\\' or @log_directory[-1..-1] == '/'
      @packet_offsets = []

      System.telemetry.reset
      @cancel = false
      @progress = 0
      @status = "Stream Ready"
      # start_config_name = System.configuration_name
      # Cosmos.check_log_configuration(@packet_log_reader, @log_filename)
      # if System.configuration_name != start_config_name
      #   @config_change_callback.call() if @config_change_callback
      # end
      @playback_index = 0
      @playback_max_index = SLIDER_GRANULARITY
      start_time = Time.utc(1970, 1, 1).sys unless start_time
      @start_time = start_time.formatted(true, 3, true)
      end_time = Time.now.sys unless end_time
      @end_time = end_time.formatted(true, 3, true)
      @start_time_object = start_time.dup
      @end_time_object = end_time.dup
      @current_time = @start_time.dup
      @current_time_object = start_time.dup
      @meta_filters = meta_filters
      @status = 'Stopped'
      @playing = false
      @playback_sleeper = nil
      @first = true
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
      if (@mode == :stream or @log_filename) and !@thread
        @playback_index = 0 if @playback_index < 0
        start_playback(:FORWARD)
      else
        stop()
      end
    end

    # Replay start playing backward
    def reverse_play
      if (@mode == :stream or @log_filename) and !@thread
        @playback_index = @packet_offsets.length - 2 if @mode != :stream and @playback_index >= @packet_offsets.length
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
      if (@mode == :stream or @log_filename) and !@thread
        if @mode == :stream
          @playback_index = 0
          @current_time = @start_time.dup
          @current_time_object = @start_time_object.dup
        else
          packet = read_at_index(0, :FORWARD)
          @start_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
        end
      else
        stop()
      end
    end

    # Replay move to end of file
    def move_end
      if (@mode == :stream or @log_filename) and !@thread
        if @mode == :stream
          @playback_index = SLIDER_GRANULARITY
          @current_time = @end_time.dup
          @current_time_object = @end_time_object.dup
        else
          packet = read_at_index(@packet_offsets.length - 1, :FORWARD)
          @end_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time
        end
      else
        stop()
      end
    end

    # Replay move to index
    #
    # @param index [Integer] packet index into file
    def move_index(index)
      if (@mode == :stream or @log_filename) and !@thread
        if @mode == :stream
          @playback_index = index
          total_seconds = @end_time_object - @start_time_object
          delta = (total_seconds / SLIDER_GRANULARITY.to_f) * index
          @current_time_object = @start_time_object + delta
          @current_time = @current_time_object.formatted(true, 3, true)
        else
          read_at_index(index, :FORWARD)
        end
      else
        stop()
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
        packet_count = 0
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
              packet_count += 1

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
              packet_count += 1
              previous_packet = packet
            end
          end
        rescue Exception => error
          Logger.error "Error in Playback Thread\n#{error.formatted}"
        ensure
          Logger.info "Replayed Packet Count = #{packet_count}"
          @status = 'Stopped'
          @playing = false
          @playback_sleeper = nil
          @thread = nil
          @interface.disconnect
        end
      end
    end

    def read_at_index(index, direction)
      if @mode == :file
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
          @current_time_object = packet.received_time
          @current_time = packet.received_time.formatted(true, 3, true) if packet and packet.received_time

          return packet
        else
          return nil
        end
      else
        unless @interface.connected?
          request_packet = Cosmos::Packet.new('DART', 'DART')
          request_packet.define_item('REQUEST', 0, 0, :BLOCK)

          request = {}
          if direction == :FORWARD
            request['start_time_sec'] = @current_time_object.tv_sec
            request['start_time_usec'] = @current_time_object.tv_usec
            request['end_time_sec'] = @end_time_object.tv_sec
            request['end_time_usec'] = @end_time_object.tv_usec
          else
            request['start_time_sec'] = @current_time_object.tv_sec
            request['start_time_usec'] = @current_time_object.tv_usec
            request['end_time_sec'] = @start_time_object.tv_sec
            request['end_time_usec'] = @start_time_object.tv_usec
          end
          request['cmd_tlm'] = 'TLM'
          request['meta_filters'] = @meta_filters unless @meta_filters.empty?
          request_packet.write('REQUEST', JSON.dump(request))

          @interface.connect
          @interface.write(request_packet)
        end

        packet = @interface.read
        unless packet
          @interface.disconnect
          return nil
        end

        # Switch to correct configuration from SYSTEM META when needed
        if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
          meta_packet = System.telemetry.update!('SYSTEM', 'META', packet.buffer)
          Cosmos::System.load_configuration(meta_packet.read('CONFIG'))
        end
        handle_packet(packet)

        @current_time_object = packet.received_time
        @current_time = packet.received_time.formatted(true, 3, true)
        if @first
          @first = false
          @start_time_object = @current_time_object.dup
          @start_time = @current_time.dup
        end
        @playback_index = ((((@end_time_object - @start_time_object) - (@end_time_object - @current_time_object)).to_f / (@end_time_object - @start_time_object).to_f) * SLIDER_GRANULARITY).to_i

        return packet
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
