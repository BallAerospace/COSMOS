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
    # @return [MessageLog] Message log for the CmdTlmServer
    instance_attr_reader :message_log
    # @return [JsonDRb] Provides access to the server for all tools both
    #   internal and external
    instance_attr_accessor :json_drb
    # @return [String] CmdTlmServer title as set in the config file
    instance_attr_accessor :title

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

    # The default host
    DEFAULT_HOST = 'localhost'
    # The default configuration file name
    DEFAULT_CONFIG_FILE = File.join(Cosmos::USERPATH, 'config', 'tools', 'cmd_tlm_server', 'cmd_tlm_server.txt')
    # The maximum number of limits events that are queued. Used when
    # subscribing to limits events.
    DEFAULT_LIMITS_EVENT_QUEUE_SIZE = 1000
    # The maximum number of packets that are queued. Used when subscribing to
    # packet data.
    DEFAULT_PACKET_DATA_QUEUE_SIZE = 1000

    @@instance = nil
    @@meta_callback = nil

    # Get the instance of the CmdTlmServer
    def self.instance
      @@instance
    end

    # Set the meta callback
    def self.meta_callback= (meta_callback)
      @@meta_callback = meta_callback
    end

    # Constructor for a CmdTlmServer
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
    def initialize(config_file = DEFAULT_CONFIG_FILE,
                   production = false,
                   disconnect = false,
                   create_message_log = true)
      @@instance = self
      @packet_logging = nil # Removes warnings
      @message_log = MessageLog.new('server') if create_message_log

      super() # For Api

      Logger.info "COSMOS Version: #{COSMOS_VERSION}"

      @disconnect = disconnect

      @limits_event_queue_mutex = Mutex.new
      @limits_event_queues = {}
      @next_limits_event_queue_id = 1

      @packet_data_queue_mutex = Mutex.new
      @packet_data_queues = {}
      @next_packet_data_queue_id = 1

      # Process cmd_tlm_server.txt
      @config = CmdTlmServerConfig.new(config_file)
      @background_tasks = BackgroundTasks.new(@config)
      @commanding = Commanding.new(@config)
      @interfaces = Interfaces.new(@config, method(:identified_packet_callback))
      @packet_logging = PacketLogging.new(@config)
      @routers = Routers.new(@config)
      @title = @config.title
      @stop_callback = nil

      # Set Threads to kill CTS if they throw an exception
      Thread.abort_on_exception = true

      # Don't start the DRb service or the telemetry monitoring thread
      # if we started the server in disconnect mode
      @json_drb = nil
      start(production) unless @disconnect
    end # end def initialize

    # Start up the system by starting the JSON-RPC server, interfaces, routers,
    # and background tasks. Starts a thread to monitor all packets for
    # staleness so other tools (such as Packet Viewer or Telemetry Viewer) can
    # react accordingly.
    #
    # @param production (see #initialize)
    def start(production = false)
      System.telemetry # Make sure definitions are loaded by starting anything
      return unless @json_drb.nil?

      @@meta_callback.call(@config.meta_target_name, @config.meta_packet_name) if @@meta_callback if @config.meta_target_name and @config.meta_packet_name

      # Start DRb with access control
      @json_drb = JsonDRb.new
      @json_drb.acl = System.acl if System.acl

      # In production we start logging and don't allow the user to stop it
      # We also disallow setting telemetry and disconnecting from interfaces
      if production
        @packet_logging.start
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
        @json_drb.start_service("localhost", System.ports['CTS_API'], self)
      rescue Exception
        # Call packet_logging shutdown here to explicitly kill the logging
        # threads since this CTS is not going to launch
        @packet_logging.shutdown
        raise FatalError.new("Error starting JsonDRb on port #{System.ports['CTS_API']}.\nPerhaps a Command and Telemetry Server is already running?")
      end

      @routers.add_preidentified('PREIDENTIFIED_ROUTER', System.instance.ports['CTS_PREIDENTIFIED'])
      @routers.add_cmd_preidentified('PREIDENTIFIED_CMD_ROUTER', System.instance.ports['CTS_CMD_ROUTER'])
      System.telemetry.limits_change_callback = method(:limits_change_callback)
      @interfaces.start
      @routers.start
      @background_tasks.start_all

      # Start staleness monitor thread
      @sleeper = Sleeper.new
      @staleness_monitor_thread = Thread.new do
        begin
          while true
            stale = System.telemetry.check_stale
            stale.each do |packet|
              post_limits_event(:STALE_PACKET, [packet.target_name, packet.packet_name])
            end
            broken = @sleeper.sleep(10)
            break if broken
          end
        rescue Exception => err
          Logger.fatal "Staleness Monitor thread unexpectedly died"
          Cosmos.handle_fatal_exception(err)
        end
      end # end Thread.new
    end

    # Properly shuts down the command and telemetry server by stoping the
    # JSON-RPC server, background tasks, routers, and interfaces. Also kills
    # the packet staleness monitor thread.
    def stop
      # Shutdown DRb
      @json_drb.stop_service

      # Shutdown staleness monitor thread
      Cosmos.kill_thread(self, @staleness_monitor_thread)

      @background_tasks.stop_all
      @routers.stop
      @interfaces.stop
      @packet_logging.shutdown
      @stop_callback.call if @stop_callback
      @message_log.stop if @message_log

      @json_drb = nil
    end

    # Set a stop callback
    def stop_callback= (stop_callback)
      @stop_callback = stop_callback
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
        case item.limits.state
        when :BLUE
          Logger.info "<B>#{tgt_pkt_item_str} #{item.limits.state}"
        when :GREEN, :GREEN_LOW, :GREEN_HIGH
          Logger.info "<G>#{tgt_pkt_item_str} #{item.limits.state}"
        when :YELLOW, :YELLOW_LOW, :YELLOW_HIGH
          Logger.warn "<Y>#{tgt_pkt_item_str} #{item.limits.state}"
        when :RED, :RED_LOW, :RED_HIGH
          Logger.error "<R>#{tgt_pkt_item_str} #{item.limits.state}"
        else
          Logger.error "#{tgt_pkt_item_str} UNKNOWN"
        end
      end

      post_limits_event(:LIMITS_CHANGE, [packet.target_name, packet.packet_name, item.name, old_limits_state, item.limits.state])

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

    # Post a limits event to all subscribed limits event listeners.
    #
    # @param event_type [Symbol] The type of limits event that occurred. Must
    #   be one of :LIMITS_SET which means the system limits set has changed,
    #   :LIMITS_CHANGE which means an individual item has changed limits state,
    #   :LIMITS_SETTINGS which means an individual item has new settings, or
    #   :STALE_PACKET which means a packet with limits has gone stale
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
            queue, queue_size = @limits_event_queues.delete(id)
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
        queue, queue_size = @@instance.limits_event_queues.delete(id)
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
                received_time ||= Time.now
                queue << [packet.buffer, target_name, packet_name,
                  received_time.tv_sec, received_time.tv_usec, packet.received_count]
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
            queue, packets, queue_size = @packet_data_queues.delete(id)
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
      packets.length.times do |index|
        upcase_packets << []
        upcase_packets[index][0] = packets[index][0].upcase
        upcase_packets[index][1] = packets[index][1].upcase
        # Get the packet to ensure it exists
        @@instance.get_tlm_packet(upcase_packets[index][0], upcase_packets[index][1])
      end

      @@instance.packet_data_queue_mutex.synchronize do
        id = @@instance.next_packet_data_queue_id
        @@instance.packet_data_queues[id] =
          [Queue.new, upcase_packets, queue_size]
        @@instance.next_packet_data_queue_id += 1
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
        queue, packets, queue_size = @@instance.packet_data_queues.delete(id)
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
        return queue.pop(non_block)
      else
        raise "Packet data queue with id #{id} not found"
      end
    end

    # Calls clear_counters on the System, interfaces, routers, and sets the
    # request_count on json_drb to 0.
    def self.clear_counters
      System.clear_counters
      self.instance.interfaces.clear_counters
      self.instance.routers.clear_counters
      self.instance.json_drb.request_count = 0
    end

    protected

    # Method called by all interfaces when a packet has been identified. It
    # checks the limits of the packet and then posts the packet to any
    # registered subscribers.
    #
    # @param packet [Packet] Packet which has been identified by the interface
    def identified_packet_callback(packet)
      packet.check_limits(System.limits_set)
      post_packet(packet)
    end

  end # class CmdTlmServer

end # module Cosmos
