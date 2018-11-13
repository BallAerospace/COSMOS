
# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/io/json_drb'
require 'cosmos/tools/cmd_tlm_server/api'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'
require 'cosmos/tools/cmd_tlm_server/background_tasks'
require 'cosmos/tools/cmd_tlm_server/commanding'
require 'cosmos/tools/cmd_tlm_server/interfaces'
require 'cosmos/tools/cmd_tlm_server/packet_logging'
require 'cosmos/tools/cmd_tlm_server/routers'
require 'cosmos/tools/cmd_tlm_server/replay_backend'

module Cosmos
  # Provides the interface for all applications to get the latest telemetry and
  # to send commands.
  class CmdTlmServer
    include Api

    # instance_attr_reader attributes are used by other classes and are thus
    # made available directly on the CmdTlmServer class

    # @return [BackgroundTasks] Access to the background tasks
    instance_attr_reader :background_tasks
    # @return [Commanding] Allows for sending commands to targets and
    #   interfaces
    instance_attr_reader :commanding
    # @return [Interfaces] Access to the interfaces
    instance_attr_reader :interfaces
    # @return [PacketLogging] Access to the packet loggers
    instance_attr_reader :packet_logging
    # @return [Routers] Access to the routers
    instance_attr_reader :routers
    # @return [ReplayBackend] Access to replay logic
    instance_attr_reader :replay_backend
    # @return [MessageLog] Message log for the CmdTlmServer
    instance_attr_reader :message_log
    # @return [JsonDRb] Provides access to the server for all tools both
    #   internal and external
    instance_attr_accessor :json_drb
    # @return [String] CmdTlmServer title as set in the config file
    instance_attr_accessor :title
    # @return [Symbol] mode :CMD_TLM_SERVER or :REPLAY
    instance_attr_accessor :mode

    # attr_reader attributes are only used by CmdTlmServer internally and are
    # thus only available as attributes on the singleton

    # @return [Mutex] Synchronization object around limits events
    attr_reader :limits_event_queue_mutex
    # @return [Hash<Integer, Array<Queue, Integer>>] The limits event queues
    #   hashed by id. Returns an array containing the queue followed by the
    #   queue size.
    attr_reader :limits_event_queues
    # @return [Integer] The next limits event queue id when
    #   subscribe_limits_event is called. This ID must be used in the
    #   limits_event_queues hash to access the queue.
    attr_accessor :next_limits_event_queue_id
    # @return [Mutex] Synchronization object around packet data events
    attr_reader :packet_data_queue_mutex
    # @return [Hash<Integer, Array<Queue, Integer>>] The packet data queues
    #   hashed by id. Returns an array containing the queue followed by the
    #   queue size.
    attr_reader :packet_data_queues
    # @return [Integer] The next packet data queue id when
    #   subscribe_packet_data is called. This ID must be used in the
    #   packet_data_queues hash to access the queue.
    attr_accessor :next_packet_data_queue_id
    # @return [Mutex] Synchronization object around server messages
    attr_reader :server_message_queue_mutex
    # @return [Hash<Integer, Array<Queue, Integer>>] The server message queues
    #   hashed by id. Returns an array containing the queue followed by the
    #   queue size.
    attr_reader :server_message_queues
    # @return [Integer] The next server message queue id when
    #   subscribe_server_messages is called. This ID must be used in the
    #   server_message_queues hash to access the queue.
    attr_accessor :next_server_message_queue_id
    # @return [Boolean] Whether the server was created in disconnect mode
    attr_reader :disconnect

    # The default configuration file name
    DEFAULT_CONFIG_FILE = File.join(Cosmos::USERPATH, 'config', 'tools', 'cmd_tlm_server', 'cmd_tlm_server.txt')
    # The maximum number of limits events that are queued. Used when
    # subscribing to limits events.
    DEFAULT_LIMITS_EVENT_QUEUE_SIZE = 1000
    # The maximum number of packets that are queued. Used when subscribing to
    # packet data.
    DEFAULT_PACKET_DATA_QUEUE_SIZE = 1000
    # The maximum number of server messages that are queued. Used when subscribing to
    # server messages.
    DEFAULT_SERVER_MESSAGES_QUEUE_SIZE = 1000

    @@instance = nil
    @@meta_callback = nil

    # Get the instance of the CmdTlmServer
    def self.instance
      @@instance
    end

    # Set the meta callback
    def self.meta_callback=(meta_callback)
      @@meta_callback = meta_callback
    end

    # Constructor for a CmdTlmServer.  Initializes all internal state and
    # starts up the sever
    #
    # @param config_file [String] The name of the server configuration file
    #   which must be in the config/tools/cmd_tlm_server directory.
    # @param production [Boolean] Whether the server should be placed in
    #   'production' mode which does various things to protect the server
    #   including disabling the ability to stop logging.
    # @param disconnect [Boolean] Whether to start the server in a disconnected
    #   stand-alone mode which does not actually use the interfaces to send and
    #   receive data. This is useful for testing scripts when actual hardware
    #   is not available.
    # @param mode [Symbol] :CMD_TLM_SERVER or :REPLAY - Defines overall mode
    # @param replay_routers [Boolean] Whether to keep existing routers when starting
    #   the server in REPLAY mode. Default is false which means to clear all
    #   existing routers and simply create the preidentified routers.
    def initialize(
      config_file = DEFAULT_CONFIG_FILE,
      production = false,
      disconnect = false,
      mode = :CMD_TLM_SERVER,
      replay_routers = false)

      @@instance = self
      @packet_logging = nil # Removes warnings
      @mode = mode

      super() # For Api

      Logger.info "COSMOS Version: #{COSMOS_VERSION}"

      @disconnect = disconnect

      @limits_event_queue_mutex = Mutex.new
      @limits_event_queues = {}
      @next_limits_event_queue_id = 1
      @packet_data_queue_mutex = Mutex.new
      @packet_data_queues = {}
      @next_packet_data_queue_id = 1
      @server_message_queue_mutex = Mutex.new
      @server_message_queues = {}
      @next_server_message_queue_id = 1

      # Process cmd_tlm_server.txt
      @config = CmdTlmServerConfig.new(config_file)
      @background_tasks = BackgroundTasks.new(@config)
      @commanding = Commanding.new(@config)
      @interfaces = Interfaces.new(@config, method(:identified_packet_callback))
      @packet_logging = PacketLogging.new(@config)
      @routers = Routers.new(@config)
      @replay_backend = ReplayBackend.new(@config)
      @title = @config.title
      if @mode != :CMD_TLM_SERVER
        @title.gsub!("Command and Telemetry Server", "Replay")
      end
      @stop_callback = nil
      @reload_callback = nil

      # Set Threads to kill CTS if they throw an exception
      Thread.abort_on_exception = true

      # Don't start the DRb service or the telemetry monitoring thread
      # if we started the server in disconnect mode
      @json_drb = nil
      unless @disconnect
        System.telemetry # Make sure definitions are loaded by starting anything

        @@meta_callback.call() if @@meta_callback and @config.metadata

        # Start DRb with access control
        @json_drb = JsonDRb.new
        @json_drb.acl = System.acl if System.acl

        # In production we start logging and don't allow the user to stop it
        # We also disallow setting telemetry and disconnecting from interfaces
        if production
          @api_whitelist.delete('stop_logging')
          @api_whitelist.delete('stop_cmd_log')
          @api_whitelist.delete('stop_tlm_log')
          @interfaces.all.each do |name, interface|
            interface.disable_disconnect = true
          end
          @routers.all.each do |name, interface|
            interface.disable_disconnect = true
          end
        end
        @json_drb.method_whitelist = @api_whitelist
        begin
          if @mode == :CMD_TLM_SERVER
            @json_drb.start_service(System.listen_hosts['CTS_API'], System.ports['CTS_API'], self)
          else
            @json_drb.start_service(System.listen_hosts['REPLAY_API'], System.ports['REPLAY_API'], self)
          end
        rescue Exception
          # Call packet_logging shutdown here to explicitly kill the logging
          # threads since this CTS is not going to launch
          @packet_logging.shutdown
          if @mode == :CMD_TLM_SERVER
            raise FatalError.new("Error starting JsonDRb on port #{System.ports['CTS_API']}.\nPerhaps a Command and Telemetry Server is already running?")
          else
            raise FatalError.new("Error starting JsonDRb on port #{System.ports['REPLAY_API']}.\nPerhaps another Replay is already running?")
          end
        end

        if @mode == :CMD_TLM_SERVER
          @routers.add_preidentified('PREIDENTIFIED_ROUTER', System.ports['CTS_PREIDENTIFIED'])
          @routers.add_cmd_preidentified('PREIDENTIFIED_CMD_ROUTER', System.ports['CTS_CMD_ROUTER'])
        else
          # Create dummy interface for Replay so we can attach the preidentified routers to it.
          # This is needed because interfaces are not mapped to targets when loading a saved_config.
          # Since interfaces are used to access the routers, nothing is send out the preidentified
          # interface port and TlmGrapher (most notably) does not work.
          @replay_interface = Interface.new
          @replay_interface.name = "REPLAY"
          @routers.all.clear unless replay_routers
          @replay_interface.routers << @routers.add_preidentified('PREIDENTIFIED_ROUTER', System.ports['REPLAY_PREIDENTIFIED'])
          @replay_interface.cmd_routers << @routers.add_cmd_preidentified('PREIDENTIFIED_CMD_ROUTER', System.ports['REPLAY_CMD_ROUTER'])
        end
        System.telemetry.limits_change_callback = method(:limits_change_callback)
        @routers.start

        start(production)
      end
    end

    # Map any targets without interfaces to the dummy replay interface.
    # Targets will only have an interface already mapped if the replay_routers
    # flag was passed to the server.
    def replay_map_targets_to_interfaces
      # Try to map existing interfaces to targets
      if @interfaces
        @interfaces.all.each do |name, interface|
          interface.target_names.each do |target|
            System.targets[target].interface = interface
          end
        end
      end
      # If any remaing targets don't have an interface map to the @replay_interface
      System.targets.each do |name, target|
        target.interface = @replay_interface unless target.interface
      end
    end

    # Properly shuts down the command and telemetry server by stoping the
    # JSON-RPC server, background tasks, routers, and interfaces. Also kills
    # the packet staleness monitor thread.  This is final and the server cannot be
    # restarted, it must be recreated
    def stop
      # Break long pollers
      @limits_event_queues.dup.each do |id, data|
        queue, _ = @limits_event_queues.delete(id)
        queue << nil if queue
      end

      @server_message_queues.dup.each do |id, data|
        queue, _ = @server_message_queues.delete(id)
        queue << nil if queue
      end

      @packet_data_queues.dup.each do |id, data|
        queue, _, _ = @packet_data_queues.delete(id)
        queue << nil if queue
      end

      # Shutdown DRb
      @json_drb.stop_service if @json_drb
      @routers.stop

      if @mode == :CMD_TLM_SERVER
        # Shutdown staleness monitor thread
        Cosmos.kill_thread(self, @staleness_monitor_thread)

        @background_tasks.stop_all
        @interfaces.stop
        @packet_logging.shutdown
      else
        @replay_backend.shutdown
      end
      @stop_callback.call if @stop_callback
      @message_log.stop if @message_log
    end

    # Set a stop callback
    def stop_callback=(stop_callback)
      @stop_callback = stop_callback
    end

    # Reload the default configuration
    def reload
      @replay_backend.shutdown if @mode != :CMD_TLM_SERVER
      if @reload_callback
        @reload_callback.call(false)
      else
        System.reset
      end
    end

    # Set a reload callback
    def reload_callback=(reload_callback)
      @reload_callback = reload_callback
    end

    # Gracefully kill the staleness monitor thread
    def graceful_kill
      @sleeper.cancel
    end

    # Called when an item in any packet changes limits states.
    #
    # @param packet [Packet] Packet which has had an item change limits state
    # @param item [PacketItem] The item which has changed limits state
    # @param old_limits_state [Symbol] The previous state of the item. See
    #   {PacketItemLimits#state}
    # @param value [Object] The current value of the item
    # @param log_change [Boolean] Whether to log this limits change event
    def limits_change_callback(packet, item, old_limits_state, value, log_change)
      if log_change
        # Write to Server Messages that limits state has changed
        tgt_pkt_item_str = "#{packet.target_name} #{packet.packet_name} #{item.name} = #{value} is"
        packet_time = packet.packet_time
        pkt_time_str = ""
        pkt_time_str << " (#{packet.packet_time.sys.formatted})" if packet_time
        case item.limits.state
        when :BLUE
          Logger.info "<B>#{tgt_pkt_item_str} #{item.limits.state}#{pkt_time_str}"
        when :GREEN, :GREEN_LOW, :GREEN_HIGH
          Logger.info "<G>#{tgt_pkt_item_str} #{item.limits.state}#{pkt_time_str}"
        when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
          Logger.warn "<Y>#{tgt_pkt_item_str} #{item.limits.state}#{pkt_time_str}"
        when :RED, :RED_LOW, :RED_HIGH
          Logger.error "<R>#{tgt_pkt_item_str} #{item.limits.state}#{pkt_time_str}"
        else
          Logger.error "#{tgt_pkt_item_str} UNKNOWN#{pkt_time_str}"
        end
      end

      post_limits_event(:LIMITS_CHANGE, [packet.target_name, packet.packet_name, item.name, old_limits_state, item.limits.state, packet_time ? packet_time.tv_sec : nil, packet_time ? packet_time.tv_usec : nil])

      if @mode == :CMD_TLM_SERVER
        if item.limits.response
          begin
            item.limits.response.call(packet, item, old_limits_state)
          rescue Exception => err
            Logger.error "#{packet.target_name} #{packet.packet_name} #{item.name} Limits Response Exception!"
            Logger.error "Called with old_state = #{old_limits_state}, new_state = #{item.limits.state}"
            Logger.error err.formatted
          end
        end
      end
    end

    # Post a limits event to all subscribed limits event listeners.
    #
    # @param event_type [Symbol] The type of limits event that occurred. Must
    #   be one of :LIMITS_SET which means the system limits set has changed,
    #   :LIMITS_CHANGE which means an individual item has changed limits state,
    #   :LIMITS_SETTINGS which means an individual item has new settings, or
    #   :STALE_PACKET which means a packet with limits has gone stale
    #   :STALE_PACKET_RCVD which means a packet with limits that had previously
    #   been stale is no longer stale.
    # @param event_data [Symbol|Array<String,String,String,Symbol,Symbol>]
    #   Returns the current limits set name for event_type == :LIMITS_SET.
    #   Returns an array containing the target name, packet name, item name,
    #   old limits state, and current limits state for event_type ==
    #   :LIMITS_CHANGE.
    def post_limits_event(event_type, event_data)
      if @limits_event_queues.length > 0
        queues_to_drop = []

        @limits_event_queue_mutex.synchronize do
          # Post event to active queues
          @limits_event_queues.each do |id, data|
            queue = data[0]
            queue_size = data[1]
            queue << [event_type, event_data]
            if queue.length > queue_size
              # Drop queue
              queues_to_drop << id
            end
          end

          # Drop queues which are not being serviced
          queues_to_drop.each do |id|
            # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
            # that might otherwise be left blocking forever for something on the queue
            queue, _ = @limits_event_queues.delete(id)
            queue << nil if queue
          end
        end
      end
    end

    # Create a queue on the CmdTlmServer that gets populated with every limits
    # event in the system. A limits event occurs when a telemetry item with
    # limits changes state. Thus limits events occur on negative transitions
    # (:GREEN to :YELLOW_LOW) and positive transitions (:YELLOW_HIGH to
    # :GREEN).
    #
    # @param queue_size [Integer] The number of limit events to accumulate
    #   before the queue will be dropped due to inactivity.
    # @return [Integer] The queue ID returned from the CmdTlmServer. Use this
    #   ID when calling {#get_limits_event} and {#unsubscribe_limits_events}.
    def self.subscribe_limits_events(queue_size = DEFAULT_LIMITS_EVENT_QUEUE_SIZE)
      unless queue_size.is_a? Integer and queue_size > 0
        raise ArgumentError, "Invalid queue size for subscribe_limits_events: #{queue_size}"
      end

      id = nil
      @@instance.limits_event_queue_mutex.synchronize do
        id = @@instance.next_limits_event_queue_id
        @@instance.limits_event_queues[id] = [Queue.new, queue_size]
        @@instance.next_limits_event_queue_id += 1
      end
      return id
    end

    # Unsubscribe from being notified for every limits event in the system.
    # This deletes the queue and further calls to {#get_limits_event} will
    # raise an exception.
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_limits_events}
    def self.unsubscribe_limits_events(id)
      queue = nil
      @@instance.limits_event_queue_mutex.synchronize do
        # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
        # that might otherwise be left blocking forever for something on the queue
        queue, _ = @@instance.limits_event_queues.delete(id)
        queue << nil if queue
      end
    end

    # Get a limits event from the queue created by {#subscribe_limits_events}.
    #
    # Each limits event consists of an Array with two elements:
    #   The Symbol name of the event and an Array of data
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_limits_events}
    # @param non_block [Boolean] Whether to wait on the queue for the next
    #   limits event before returning. Default is to block waiting for the next
    #   event. NOTE: If you pass true and there is no data on the queue, a
    #   ThreadError exception is raised.
    def self.get_limits_event(id, non_block = false)
      queue = nil
      @@instance.limits_event_queue_mutex.synchronize do
        queue, _ = @@instance.limits_event_queues[id]
      end
      if queue
        return queue.pop(non_block)
      else
        raise "Limits event queue with id #{id} not found"
      end
    end

    # Post packet data to all subscribed packet data listeners.
    #
    # @param packet [Packet]
    def post_packet(packet)
      if @packet_data_queues.length > 0
        queues_to_drop = []

        @packet_data_queue_mutex.synchronize do
          # Post event to active queues
          @packet_data_queues.each do |id, data|
            queue = data[0]
            packets = data[1]
            queue_size = data[2]

            packets.each do |target_name, packet_name|
              if packet.target_name == target_name and packet.packet_name == packet_name
                received_time = packet.received_time
                received_time ||= Time.now.sys
                queue << [packet.buffer, target_name, packet_name,
                  received_time.tv_sec, received_time.tv_usec, packet.received_count, packet.stored, packet.extra]
                if queue.length > queue_size
                  # Drop queue
                  queues_to_drop << id
                end
                break
              end
            end
          end

          # Drop queues which are not being serviced
          queues_to_drop.each do |id|
            # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
            # that might otherwise be left blocking forever for something on the queue
            queue, _, _ = @packet_data_queues.delete(id)
            queue << nil if queue
          end
        end
      end
    end

    # Subscribe to one or more telemetry packets.
    #
    # @param packets [Array<Array<String,String>>] List of packets where the
    #   Strings are target name, packet name.
    # @param queue_size [Integer] The size of the queue to store packet data
    # @return [Integer] The queue ID returned from CmdTlmServer. Use this ID
    #   when calling {#get_packet_data} and {#unsubscribe_packet_data}.
    def self.subscribe_packet_data(packets,
                                   queue_size = CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE)
      if !packets.is_a?(Array) || !packets[0].is_a?(Array)
        raise ArgumentError, "packets must be nested array: [['TGT','PKT'],...]"
      end

      unless queue_size.is_a? Integer and queue_size > 0
        raise ArgumentError, "Invalid queue size for subscribe_packet_data: #{queue_size}"
      end

      id = nil
      upcase_packets = []

      # Upper case packet names
      need_meta = false
      packets.length.times do |index|
        upcase_packets << []
        upcase_packets[index][0] = packets[index][0].upcase
        upcase_packets[index][1] = packets[index][1].upcase

        # Get the packet to ensure it exists
        if @@instance.disconnect
          @last_subscribed_packet = System.telemetry.packet(upcase_packets[index][0], upcase_packets[index][1])
        else
          @@instance.get_tlm_packet(upcase_packets[index][0], upcase_packets[index][1])
        end

        if upcase_packets[index][0] == 'SYSTEM' and upcase_packets[index][1] == 'META'
          need_meta = true
        end
      end

      @@instance.packet_data_queue_mutex.synchronize do
        id = @@instance.next_packet_data_queue_id
        @@instance.packet_data_queues[id] =
          [Queue.new, upcase_packets, queue_size]
        @@instance.next_packet_data_queue_id += 1

        # Send the current meta packet first if requested
        if need_meta
          packet = System.telemetry.packet('SYSTEM', 'META')
          received_time = packet.received_time
          received_time ||= Time.now.sys
          @@instance.packet_data_queues[id][0] << [packet.buffer, 'SYSTEM', 'META',
            received_time.tv_sec, received_time.tv_usec, packet.received_count, packet.stored, packet.extra]
        end
      end
      return id
    end

    # Unsubscribe to telemetry packets.
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_packet_data}.
    def self.unsubscribe_packet_data(id)
      @@instance.packet_data_queue_mutex.synchronize do
        # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
        # that might otherwise be left blocking forever for something on the queue
        queue, _, _ = @@instance.packet_data_queues.delete(id)
        queue << nil if queue
      end
      return nil
    end

    # Get packet data from the queue created by {#subscribe_packet_data}.
    #
    # Each packet data consists of an Array with five elements:
    # \[buffer, target name, packet name, received time sec, received time us]
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_packet_data}
    # @param non_block [Boolean] Whether to wait on the queue for the next
    #   packet before returning. Default is to block waiting for the next
    #   packet. NOTE: If you pass true and there is no packet on the queue, a
    #   ThreadError exception is raised.
    def self.get_packet_data(id, non_block = false)
      queue = nil
      @@instance.packet_data_queue_mutex.synchronize do
        queue, _, _ = @@instance.packet_data_queues[id]
      end
      if queue
        if @@instance.disconnect
          begin
            return queue.pop(true)
          rescue ThreadError
            received_time ||= Time.now.sys
            return [@last_subscribed_packet.buffer, @last_subscribed_packet.target_name,
              @last_subscribed_packet.packet_name, received_time.tv_sec, received_time.tv_usec, @last_subscribed_packet.received_count, @last_subscribed_packet.stored, @last_subscribed_packet.extra]
          end
        else
          return queue.pop(non_block)
        end
      else
        raise "Packet data queue with id #{id} not found"
      end
    end

    # Post a server message to all subscribed server message listeners.
    # Messages are formatted as [Text, Color], e.g. ["Msg1","RED"]
    #
    # @param message [Array<String, String>] Server message
    def post_server_message(message)
      if @server_message_queues.length > 0
        queues_to_drop = []

        @server_message_queue_mutex.synchronize do
          # Post event to active queues
          @server_message_queues.each do |id, data|
            queue = data[0]
            queue_size = data[1]
            queue << message
            if queue.length > queue_size
              # Drop queue
              queues_to_drop << id
            end
          end

          # Drop queues which are not being serviced
          queues_to_drop.each do |id|
            # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
            # that might otherwise be left blocking forever for something on the queue
            queue, _ = @server_message_queues.delete(id)
            queue << nil if queue
          end
        end
      end
    end

    # Create a queue on the CmdTlmServer that gets populated with every message
    # in the system.
    #
    # @param queue_size [Integer] The number of server messages to accumulate
    #   before the queue will be dropped due to inactivity.
    # @return [Integer] The queue ID returned from the CmdTlmServer. Use this
    #   ID when calling {#get_server_message} and {#unsubscribe_server_messages}.
    def self.subscribe_server_messages(queue_size = DEFAULT_SERVER_MESSAGES_QUEUE_SIZE)
      unless queue_size.is_a? Integer and queue_size > 0
        raise ArgumentError, "Invalid queue size for subscribe_server_messages: #{queue_size}"
      end

      id = nil
      @@instance.server_message_queue_mutex.synchronize do
        id = @@instance.next_server_message_queue_id
        @@instance.server_message_queues[id] = [Queue.new, queue_size]
        @@instance.next_server_message_queue_id += 1
      end
      return id
    end

    # Unsubscribe from being notified for every server message in the system.
    # This deletes the queue and further calls to {#get_server_message} will
    # raise an exception.
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_server_messages}
    def self.unsubscribe_server_messages(id)
      queue = nil
      @@instance.server_message_queue_mutex.synchronize do
        # Remove the queue to stop servicing it.  Nil is added to unblock any client threads
        # that might otherwise be left blocking forever for something on the queue
        queue, _ = @@instance.server_message_queues.delete(id)
        queue << nil if queue
      end
    end

    # Get a server message from the queue created by {#subscribe_server_messages}.
    #
    # Each server message consists of a String
    #
    # @param id [Integer] The queue ID received from calling
    #   {#subscribe_server_messages}
    # @param non_block [Boolean] Whether to wait on the queue for the next
    #   server message before returning. Default is to block waiting for the next
    #   message. NOTE: If you pass true and there is no data on the queue, a
    #   ThreadError exception is raised.
    def self.get_server_message(id, non_block = false)
      queue = nil
      @@instance.server_message_queue_mutex.synchronize do
        queue, _ = @@instance.server_message_queues[id]
      end
      if queue
        return queue.pop(non_block)
      else
        raise "Server message queue with id #{id} not found"
      end
    end

    # Calls clear_counters on the System, interfaces, routers, and sets the
    # request_count on json_drb to 0.
    def self.clear_counters
      System.clear_counters
      self.instance.interfaces.clear_counters if self.instance.interfaces
      self.instance.routers.clear_counters
      self.instance.json_drb.request_count = 0
    end

    # Method called by all interfaces when a packet has been identified. It
    # checks the limits of the packet and then posts the packet to any
    # registered subscribers.
    #
    # @param packet [Packet] Packet which has been identified by the interface
    def identified_packet_callback(packet)
      packet.check_limits(System.limits_set)
      post_packet(packet)
    end

    private

    # Start up the system by starting the JSON-RPC server, interfaces, routers,
    # and background tasks. Starts a thread to monitor all packets for
    # staleness so other tools (such as Packet Viewer or Telemetry Viewer) can
    # react accordingly.
    #
    # This method is shoudl only called by initialize which is why it is private
    #
    # @param start_packet_logging [Boolean] Whether to start logging data or not
    def start(start_packet_logging = false)
      if @mode == :CMD_TLM_SERVER
        @replay_backend = nil # Remove access to Replay
        @message_log = MessageLog.new('server')
        @packet_logging.start if start_packet_logging
        @interfaces.start
        @background_tasks.start_all

        # Start staleness monitor thread
        @sleeper = Sleeper.new
        @staleness_monitor_thread = Thread.new do
          begin
            stale = []
            prev_stale = []
            while true
              # The check_stale method drives System.telemetry to iterate through
              # the packets and mark them stale as necessary.
              System.telemetry.check_stale

              # Get all stale packets that include limits items.
              stale_pkts = System.telemetry.stale(true)

              # Send :STALE_PACKET events for all newly stale packets.
              stale = []
              stale_pkts.each do |packet|
                pkt_name = [packet.target_name, packet.packet_name]
                stale << pkt_name
                post_limits_event(:STALE_PACKET, pkt_name) unless prev_stale.include?(pkt_name)
              end

              # Send :STALE_PACKET_RCVD events for all packets that were stale
              # but are no longer stale.
              prev_stale.each do |pkt_name|
                post_limits_event(:STALE_PACKET_RCVD, pkt_name) unless stale.include?(pkt_name)
              end
              prev_stale = stale.dup

              broken = @sleeper.sleep(10)
              break if broken
            end
          rescue Exception => err
            Logger.fatal "Staleness Monitor thread unexpectedly died"
            Cosmos.handle_fatal_exception(err)
          end
        end # end Thread.new
      else
        # Prevent access to interfaces or packet_logging
        @interfaces = nil
        @packet_logging = nil
      end
    end
  end
end
