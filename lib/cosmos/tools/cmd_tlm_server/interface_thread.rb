# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'redis'
require 'kafka'
require 'json'

module Cosmos

  # "Microbe Concept" - Can be run as their own process or combined as threads into a single process
  # Handles standard logging (and maybe metrics / tracing) scheme
  # Handles configuration loading?
  # Top Level Standard HTTP interface - Each microbe defines its own routes
  # Can be single file per microbe - Or rails environment
  # Needs Gemfile too though
  # And a config file?
  class Microservice

  end

  class InterfaceMicroservice

  end

  class IdentifyMicroservice

  end

  class DecomMicroservice

  end

  class CvtMicroservice

  end

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
      @interface_thread = nil
      @interface_thread_sleeper = Sleeper.new
      @identify_thread = nil
      @decom_thread = nil
      @identify_consumer = nil
      @decom_consumer = nil
      @connection_failed_messages = []
      @connection_lost_messages = []
      @mutex = Mutex.new
      @kafka_interface_client = Kafka.new(["localhost:29092"], client_id: interface.name)
      @kafka_identify_client = Kafka.new(["localhost:29092"], client_id: (interface.name + "_IDENTIFY"))
      @kafka_decom_client = Kafka.new(["localhost:29092"], client_id: (interface.name + "_DECOM"))
      @decom_topics = []
    end

    # Create and start the Ruby thread that will encapsulate the interface.
    # Creates a while loop that waits for {Interface#connect} to succeed. Then
    # calls {Interface#read} and handles all the incoming packets.
    def start
      # Build topic list for decom
      @decom_topics = []
      @interface.target_names.each do |target_name|
        packets = System.telemetry.packets(target_name)
        packets.each do |packet_name, packet|
          @decom_topics << "PACKET__#{target_name}__#{packet_name}"
        end
      end
      STDOUT.puts "#{@interface.name} starting:"
      @decom_topics.each do |topic|
        STDOUT.puts topic
      end

      @kafka_interface_producer = @kafka_interface_client.async_producer(delivery_interval: 1)
      @kafka_identify_producer = @kafka_identify_client.async_producer(delivery_interval: 1)
      @kafka_decom_producer = @kafka_decom_client.async_producer(delivery_interval: 1)

      @interface_thread_sleeper = Sleeper.new
      @interface_thread = Thread.new do
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
          if @fatal_exception_callback
            @fatal_exception_callback.call(error)
          else
            Logger.error "Packet reading thread unexpectedly died for #{@interface.name}"
            Cosmos.handle_fatal_exception(error)
          end
        end
        Logger.info "Stopped packet reading for #{@interface.name}"
      end  # Thread.new

      @identify_thread = Thread.new do
        begin
          @identify_consumer = @kafka_identify_client.consumer(group_id: "#{@interface.name}_IDENTIFY_GROUP")
          @identify_consumer.subscribe("INTERFACE__#{@interface.name}")
          @identify_consumer.each_message do |message|
            begin
              identify_packet(message)
              break if @cancel_thread
            rescue Exception => err
               STDOUT.puts err.formatted
            end
          end
        rescue Exception => error
          Logger.error "Identify thread unexpectedly died for #{@interface.name}"
          Cosmos.handle_fatal_exception(error)
        end
        Logger.info "Stopped identify for #{@interface.name}"
      end  # Thread.new

      if @decom_topics.length > 0
        @decom_thread = Thread.new do
          redis = Redis.new(url: "redis://localhost:6379/0")

          begin
            @decom_consumer = @kafka_decom_client.consumer(group_id: "#{@interface.name}_DECOM_GROUP")
            @decom_topics.each do |topic|
              @decom_consumer.subscribe(topic)
            end
            @decom_consumer.each_message do |message|
              begin
                decom_packet(redis, message)
                break if @cancel_thread
              rescue Exception => err
                STDOUT.puts err.formatted
              end
            end
          rescue Exception => error
            Logger.error "Decom thread unexpectedly died for #{@interface.name}"
            Cosmos.handle_fatal_exception(error)
          end
          Logger.info "Stopped decom for #{@interface.name}"
        end  # Thread.new
      end
    end # def start

    # Disconnect from the interface and stop the thread
    def stop
      @mutex.synchronize do
        # Need to make sure that @cancel_thread is set and the interface disconnected within
        # mutex to ensure that connect() is not called when we want to stop()
        @cancel_thread = true
        @identify_consumer.stop if @identify_consumer
        @decom_consumer.stop if @decom_consumer
        @interface_thread_sleeper.cancel
        @interface.disconnect
      end
      Cosmos.kill_thread(self, @interface_thread) if @interface_thread and @interface_thread != Thread.current
      Cosmos.kill_thread(self, @identify_thread) if @identify_thread and @identify_thread != Thread.current
      Cosmos.kill_thread(self, @decom_thread) if @decom_thread and @decom_thread != Thread.current
      @kafka_interface_producer.shutdown if @kafka_interface_producer
      @kafka_identify_producer.shutdown if @kafka_identify_producer
      @kafka_decom_producer.shutdown if @kafka_decom_producer
    end

    def graceful_kill
      # Just to avoid warning
    end

    protected

    def handle_packet(packet)
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name if packet.target_name
      headers[:packet_name] = packet.packet_name if packet.packet_name
      @kafka_interface_producer.produce(packet.buffer, topic: "INTERFACE__#{@interface.name}", :headers => headers)
    end

    def identify_packet(kafka_message)
      packet = Packet.new(nil, nil)
      #STDOUT.puts kafka_message.headers.inspect
      packet.target_name = kafka_message.headers["target_name"]
      packet.packet_name = kafka_message.headers["packet_name"]
      packet.stored = ConfigParser.handle_true_false(kafka_message.headers["stored"])
      packet.received_time = Time.parse(kafka_message.headers["time"])
      packet.buffer = kafka_message.value
      if packet.stored
        # Stored telemetry does not update the current value table
        identified_packet = System.telemetry.identify_and_define_packet(packet, @interface.target_names)
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
                                                           @interface.target_names)
          end
        else
          # Packet needs to be identified
          identified_packet = System.telemetry.identify!(packet.buffer,
                                                         @interface.target_names)
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
        string = "#{@interface.name} - Unknown #{data_length} byte packet starting: "
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
      @identified_packet_callback.call(packet) if @identified_packet_callback

      # Write to Kafka
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name
      headers[:packet_name] = packet.packet_name
      headers[:received_count] = packet.received_count
      @kafka_identify_producer.produce(packet.buffer, topic: "PACKET__#{packet.target_name}__#{packet.packet_name}", :headers => headers)

      # Write to routers
      @interface.routers.each do |router|
        begin
          router.write(packet) if router.write_allowed? and router.connected?
        rescue => err
          Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
        end
      end

      # Write to packet log writers
      if packet.stored and !@interface.stored_packet_log_writer_pairs.empty?
        @interface.stored_packet_log_writer_pairs.each do |packet_log_writer_pair|
          packet_log_writer_pair.tlm_log_writer.write(packet)
        end
      else
        @interface.packet_log_writer_pairs.each do |packet_log_writer_pair|
          # Write errors are handled by the log writer
          packet_log_writer_pair.tlm_log_writer.write(packet)
        end
      end
    end

    def decom_packet(redis, kafka_message)
      # Could also pull this by splitting the topic name
      target_name = kafka_message.headers["target_name"]
      packet_name = kafka_message.headers["packet_name"]

      packet = System.telemetry.packet(target_name, packet_name).dup
      packet.stored = ConfigParser.handle_true_false(kafka_message.headers["stored"])
      packet.received_time = Time.parse(kafka_message.headers["time"])
      packet.received_count = kafka_message.headers["received_count"].to_i
      packet.buffer = kafka_message.value

      # Need to build a JSON hash of the decomutated data
      # Thought is to support what I am calling downward typing
      # everything base name is RAW (including DERIVED)
      # Request for WITH_UNITS, etc will look down until it finds something
      # If nothing - item does not exist - nil
      # __ as seperators ITEM1, ITEM1__C, ITEM1__F, ITEM1__U

      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
      end

      #STDOUT.puts json_hash

      # Write to Kafka
      headers = {time: packet.received_time, stored: packet.stored}
      headers[:target_name] = packet.target_name
      headers[:packet_name] = packet.packet_name
      headers[:received_count] = packet.received_count
      @kafka_decom_producer.produce(json_hash.to_json, topic: "DECOM__#{target_name}__#{packet_name}", :headers => headers)

      # Write to Redis for CVT
      # TODO: This should be its own microservice pulling from Kafka
      cvt_hash = {}
      json_hash.each do |key, value|
        cvt_hash["#{target_name}__#{packet_name}__#{key}"] = value
      end

      redis.mapped_mset(cvt_hash)

      # Write to decom file
      # TODO: This should be its own microservice pulling from Kafka
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
          @interface_thread_sleeper.sleep(@interface.reconnect_delay)
        end
      else
        stop()
      end
    end
  end # class InterfaceThread

end # module Cosmos
