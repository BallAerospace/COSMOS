# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'
require 'cosmos/utilities/store'

module Cosmos
  class InterfaceCmdHandlerThread
    def initialize(interface)
      @interface = interface
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
      store = Store.new
      store.receive_commands(@interface) do |target_name, cmd_name, cmd_params, range_check, hazardous_check, raw|
        begin
          # Build the command
          begin
            command = System.commands.build_cmd(target_name, cmd_name, cmd_params, range_check, raw)
          rescue => e
            Logger.error e.formatted
            # raise e
            # TODO: Need to ack with error
            next
          end

          if hazardous_check
            hazardous, hazardous_description = System.commands.cmd_pkt_hazardous?(command)
            if hazardous
              error = HazardousError.new
              error.target_name = target_name
              error.cmd_name = cmd_name
              error.cmd_params = cmd_params
              error.hazardous_description = hazardous_description
              # raise error
              # TODO: Need to ack with hazardous error
              next
            end
          end

          begin
            @interface.write(command)
          rescue => e
            Logger.error e.formatted
            # TODO: Need to ack with error
          end
        rescue => e
          # TODO: Need to ack with error
          Logger.error e.formatted
        end
      end
    end
  end

  class InterfaceMicroservice < Microservice
    def initialize(name)
      super(name)
      interface_name = name.split("__")[1]
      @interface = Cosmos.require_class(@config['interface_params'][0]).new(*@config['interface_params'][1..-1])
      @interface.name = interface_name
      @config["target_list"].each do |item|
        @interface.target_names << item["target_name"]
      end
      # TODO: Need to set any additional interface options like protocols
      @interface_thread_sleeper = Sleeper.new
      @cancel_thread = false
      @connection_failed_messages = []
      @connection_lost_messages = []
      @mutex = Mutex.new
      @kafka_producer = @kafka_client.async_producer(delivery_interval: 1)
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
      Logger.info "Stopped packet reading for #{@interface.name}"
    end

    def handle_packet(packet)
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name if packet.target_name
      headers[:packet_name] = packet.packet_name if packet.packet_name
      @kafka_producer.produce(packet.buffer, topic: "INTERFACE__#{@interface.name}", :headers => headers)
      @kafka_producer.deliver_messages
      #Logger.info "Produce to INTERFACE__#{@interface.name}"
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
      Logger.info "#{@interface.name} Connection Success"
    end

    def disconnect
      @interface.disconnect

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
        #@identify_consumer.stop if @identify_consumer
        #@decom_consumer.stop if @decom_consumer
        @interface_thread_sleeper.cancel
        @interface.disconnect
      end
      Cosmos.kill_thread(self, @interface_thread) if @interface_thread and @interface_thread != Thread.current
      #Cosmos.kill_thread(self, @identify_thread) if @identify_thread and @identify_thread != Thread.current
      #Cosmos.kill_thread(self, @decom_thread) if @decom_thread and @decom_thread != Thread.current
      @kafka_producer.shutdown if @kafka_producer
      #@kafka_identify_producer.shutdown if @kafka_identify_producer
      #@kafka_decom_producer.shutdown if @kafka_decom_producer
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
