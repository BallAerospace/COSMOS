# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Encapsulates an {Interface} in a Ruby thread. When the thread is started by
  # the {#start} method, it loops trying to connect. It then continously reads
  # from the interface while handling the packets it receives.
  class InterfaceThread
    # The number of bytes to print when an UNKNOWN packet is received
    UNKNOWN_BYTES_TO_PRINT = 36

    # @return [#call()] Callback which is called if the #{Interface#connect}
    #   method succeeds
    attr_accessor :connection_success_callback
    # @return [#call(Exception)] Callback which is called if the
    #   {Interface#connect} method throws an exception.
    attr_accessor :connection_failed_callback
    # @return [#call(Exception|nil)] Callback which is called if the
    #   interface connection is lost.
    attr_accessor :connection_lost_callback
    # @return [#call(Packet)] Callback which is called when a packet has been
    #   received from the interface and identified.
    attr_accessor :identified_packet_callback
    # @return [#call(Exception)] Callback which is called if the
    #   InterfaceThread dies for any reason.
    attr_accessor :fatal_exception_callback

    # @param interface [Interface] The interface to create a thread for
    def initialize(interface)
      @interface = interface
      @interface.thread = self
      @connection_success_callback = nil
      @connection_failed_callback = nil
      @connection_lost_callback = nil
      @identified_packet_callback = nil
      @fatal_exception_callback = nil
      @thread = nil
      @thread_sleeper = Sleeper.new
      @connection_failed_messages = []
      @connection_lost_messages = []
      @mutex = Mutex.new
    end

    # Create and start the Ruby thread that will encapsulate the interface.
    # Creates a while loop that waits for {Interface#connect} to succeed. Then
    # calls {Interface#read} and handles all the incoming packets.
    def start
      @thread_sleeper = Sleeper.new
      @thread = Thread.new do
        @cancel_thread = false
        begin
          if @interface.read_allowed?
            Logger.info "Starting packet reading for #{@interface.name}"
          else
            Logger.info "Starting connection maintenance for #{@interface.name}"
          end
          while true
            break if @cancel_thread
            unless @interface.connected?
              begin
                @mutex.synchronize do
                  # We need to make sure connect is not called after stop() has been called
                  connect() unless @cancel_thread
                end
                break if @cancel_thread
              rescue Exception => connect_error
                handle_connection_failed(connect_error)
                if @cancel_thread
                  break
                else
                  next
                end
              end
            end

            if @interface.read_allowed?
              begin
                packet = @interface.read
                unless packet
                  Logger.info "Clean disconnect from #{@interface.name} (returned nil)"
                  handle_connection_lost(nil)
                  if @cancel_thread
                    break
                  else
                    next
                  end
                end
                packet.received_time = Time.now unless packet.received_time
              rescue Exception => err
                handle_connection_lost(err)
                if @cancel_thread
                  break
                else
                  next
                end
              end

              handle_packet(packet)
            else
              @thread_sleeper.sleep(1)
              handle_connection_lost(nil) if !@interface.connected?
            end
          end  # loop
        rescue Exception => error
          if @fatal_exception_callback
            @fatal_exception_callback.call(error)
          else
            Logger.error "Packet reading thread unexpectedly died for #{@interface.name}"
            Cosmos.handle_fatal_exception(error)
          end
        end
        Logger.info "Stopped packet reading for #{@interface.name}"
      end  # Thread.new
    end # def start

    # Disconnect from the interface and stop the thread
    def stop
      @mutex.synchronize do
        # Need to make sure that @cancel_thread is set and the interface disconnected within
        # mutex to ensure that connect() is not called when we want to stop()
        @cancel_thread = true
        @thread_sleeper.cancel
        @interface.disconnect
      end
      Cosmos.kill_thread(self, @thread) if @thread and @thread != Thread.current
    end

    def graceful_kill
      # Just to avoid warning
    end

    protected

    def handle_packet(packet)
      # Identify and update packet
      if packet.identified?
        begin
          # Preidentifed packet - place it into the current value table
          identified_packet = System.telemetry.update!(packet.target_name,
                                                       packet.packet_name,
                                                       packet.buffer)
        rescue RuntimeError
          # Packet identified but we don't know about it
          # Clear packet_name and target_name and try to identify
          Logger.warn "Received unknown identified telemetry: #{packet.target_name} #{packet.packet_name}"
          packet.target_name = nil
          packet.packet_name = nil
          identified_packet = System.telemetry.identify!(packet.buffer,
                                                         @interface.target_names)
        end
      else
        # Packet needs to be identified
        identified_packet = System.telemetry.identify!(packet.buffer,
                                                       @interface.target_names)
      end

      if identified_packet
        identified_packet.received_time = packet.received_time
        packet = identified_packet
      else
        unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
        unknown_packet.received_time = packet.received_time
        packet = unknown_packet
        data_length = packet.length
        string = "#{@interface.name} - Unknown #{data_length} byte packet starting: "
        num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
        data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
        data_to_print.each_byte do |byte|
          string << sprintf("%02X", byte)
        end
        Logger.error string
      end

      @interface.post_identify_packet(packet)
      target = System.targets[packet.target_name]
      target.tlm_cnt += 1 if target
      packet.received_count += 1
      @identified_packet_callback.call(packet) if @identified_packet_callback

      # Write to routers
      @interface.routers.each do |router|
        begin
          router.write(packet) if router.write_allowed? and router.connected?
        rescue => err
          Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
        end
      end

      # Write to packet log writers
      @interface.packet_log_writer_pairs.each do |packet_log_writer_pair|
        # Write errors are handled by the log writer
        packet_log_writer_pair.tlm_log_writer.write(packet)
      end
    end

    def handle_connection_failed(connect_error)
      if @connection_failed_callback
        @connection_failed_callback.call(connect_error)
      else
        Logger.error "#{@interface.name} Connection Failed: #{connect_error.formatted(false, false)}"
        case connect_error
        when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENOTSOCK, Errno::EHOSTUNREACH, IOError
          # Do not write an exception file for these extremely common cases
        else
          if RuntimeError === connect_error and (connect_error.message =~ /canceled/ or connect_error.message =~ /timeout/)
            # Do not write an exception file for these extremely common cases
          else
            Logger.error connect_error.formatted
            unless @connection_failed_messages.include?(connect_error.message)
              Cosmos.write_exception_file(connect_error)
              @connection_failed_messages << connect_error.message
            end
          end
        end
      end
      disconnect()
    end

    def handle_connection_lost(err)
      if @connection_lost_callback
        @connection_lost_callback.call(err)
      else
        if err
          Logger.info "Connection Lost for #{@interface.name}: #{err.formatted(false, false)}"
          case err
          when Errno::ECONNABORTED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EBADF, Errno::ENOTSOCK, IOError
            # Do not write an exception file for these extremely common cases
          else
            Logger.error err.formatted
            unless @connection_lost_messages.include?(err.message)
              Cosmos.write_exception_file(err)
              @connection_lost_messages << err.message
            end
          end
        else
          Logger.info "Connection Lost for #{@interface.name}"
        end
      end
      disconnect()
    end

    def connect
      Logger.info "Connecting to #{@interface.name}..."
      @interface.connect
      if @connection_success_callback
        @connection_success_callback.call
      else
        Logger.info "#{@interface.name} Connection Success"
      end
    end

    def disconnect
      @interface.disconnect

      # If the interface is set to auto_reconnect then delay so the thread
      # can come back around and allow the interface a chance to reconnect.
      if @interface.auto_reconnect
        if !@cancel_thread
          @thread_sleeper.sleep(@interface.reconnect_delay)
        end
      else
        stop()
      end
    end
  end # class InterfaceThread

end # module Cosmos
