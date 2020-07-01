# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'

module Cosmos
  class InterfaceCmdHandlerThread
    def initialize(interface)
      @interface = interface
      Store.instance.set_interface(@interface, initialize: true)
    end

    def start
      @thread = Thread.new do
        begin
          run()
        rescue Exception => err
          Logger.error "InterfaceCmdHandleThread died unexpectedly: #{err.formatted}"
        end
      end
    end

    def run
      Store.instance.receive_commands(@interface) do |target_name, cmd_name, cmd_params, range_check, hazardous_check, raw|
        begin
          begin
            command = System.commands.build_cmd(target_name, cmd_name, cmd_params, range_check, raw)
          rescue => e
            Logger.error e.formatted
            next e.message
          end

          if hazardous_check
            hazardous, hazardous_description = System.commands.cmd_pkt_hazardous?(command)
            if hazardous
              error = HazardousError.new
              error.target_name = target_name
              error.cmd_name = cmd_name
              error.cmd_params = cmd_params
              error.hazardous_description = hazardous_description
              next error.message
            end
          end

          begin
            @interface.write(command)
            msg_hash = { time: command.received_time.to_nsec_from_epoch,
                        target_name: command.target_name,
                        packet_name: command.packet_name,
                        received_count: command.received_count,
                        buffer: command.buffer(false) }
            Store.instance.write_topic("COMMAND__#{command.target_name}__#{command.packet_name}", msg_hash)
            Store.instance.set_interface(@interface)
          rescue => e
            Logger.error e.formatted
            next e.message
          end
        rescue => e
          Logger.error e.formatted
          next e.message
        end
        'SUCCESS'
      end
    end
  end

  class InterfaceMicroservice < Microservice
    UNKNOWN_BYTES_TO_PRINT = 16

    def initialize(name)
      super(name)
      interface_name = name.split("__")[1]
      @interface = Cosmos.require_class(@config['interface_params'][0]).new(*@config['interface_params'][1..-1])
      @interface.name = interface_name
      Store.instance.set_interface(@interface, :init => true)
      @config["target_list"].each do |item|
        @interface.target_names << item["target_name"]
      end
      # TODO: Need to set any additional interface options like protocols
      @interface_thread_sleeper = Sleeper.new
      @cancel_thread = false
      @connection_failed_messages = []
      @connection_lost_messages = []
      @mutex = Mutex.new
      @cmd_thread = InterfaceCmdHandlerThread.new(@interface)
      @cmd_thread.start
    end

    def run
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
              packet.received_time = Time.now.sys unless packet.received_time
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
            @interface_thread_sleeper.sleep(1)
            handle_connection_lost(nil) if !@interface.connected?
          end
        end  # loop
      rescue Exception => error
        Logger.error "Packet reading thread unexpectedly died for #{@interface.name}\n#{error.formatted}"
        Cosmos.handle_fatal_exception(error)
      end
      Store.instance.set_interface(@interface)
      Logger.info "Stopped packet reading for #{@interface.name}"
    end

    def handle_packet(packet)
      Store.instance.set_interface(@interface)

      if packet.stored
        # Stored telemetry does not update the current value table
        identified_packet = System.telemetry.identify_and_define_packet(packet, @target_names)
      else
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
                                                            @target_names)
          end
        else
          # Packet needs to be identified
          identified_packet = System.telemetry.identify!(packet.buffer,
                                                          @target_names)
        end
      end

      if identified_packet
        identified_packet.received_time = packet.received_time
        identified_packet.stored = packet.stored
        identified_packet.extra = packet.extra
          packet = identified_packet
      else
        unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
        unknown_packet.received_time = packet.received_time
        unknown_packet.stored = packet.stored
        unknown_packet.extra = packet.extra
        packet = unknown_packet
        data_length = packet.length
        string = "#{@interface_name} - Unknown #{data_length} byte packet starting: "
        num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
        data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
        data_to_print.each_byte do |byte|
          string << sprintf("%02X", byte)
        end
        Logger.error string
      end

      target = System.targets[packet.target_name]
      target.tlm_cnt += 1 if target
      packet.received_count += 1

      # Write to stream
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
                   stored: packet.stored,
                   target_name: packet.target_name,
                   packet_name: packet.packet_name,
                   received_count: packet.received_count,
                   buffer: packet.buffer(false) }
      Store.instance.write_topic("TELEMETRY__#{packet.target_name}__#{packet.packet_name}", msg_hash)
    end

    def handle_connection_failed(connect_error)
      Logger.error "#{@interface.name} Connection Failed: #{connect_error.formatted(false, false)}"
      case connect_error
      when Interrupt
        Logger.info "Closing from signal"
        @cancel_thread = true
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
      disconnect()
    end

    def handle_connection_lost(err)
      if err
        Logger.info "Connection Lost for #{@interface.name}: #{err.formatted(false, false)}"
        case err
        when Interrupt
          Logger.info "Closing from signal"
          @cancel_thread = true
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
      disconnect()
    end

    def connect
      Logger.info "Connecting to #{@interface.name}..."
      @interface.connect
      Store.instance.set_interface(@interface)
      Logger.info "#{@interface.name} Connection Success"
    end

    def disconnect
      @interface.disconnect
      Store.instance.set_interface(@interface)

      # If the interface is set to auto_reconnect then delay so the thread
      # can come back around and allow the interface a chance to reconnect.
      if @interface.auto_reconnect
        if !@cancel_thread
          @interface_thread_sleeper.sleep(@interface.reconnect_delay)
        end
      else
        stop()
      end
    end

    # Disconnect from the interface and stop the thread
    def stop
      @mutex.synchronize do
        # Need to make sure that @cancel_thread is set and the interface disconnected within
        # mutex to ensure that connect() is not called when we want to stop()
        @cancel_thread = true
        @interface_thread_sleeper.cancel
        @interface.disconnect
      end
      Cosmos.kill_thread(self, @interface_thread) if @interface_thread and @interface_thread != Thread.current
    end

    def shutdown(sig = nil)
      stop()
    end

    def graceful_kill
      # Just to avoid warning
    end
  end
end

Cosmos::InterfaceMicroservice.run if __FILE__ == $0
