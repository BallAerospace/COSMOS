# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/api'
require 'cosmos/io/raw_logger_pair'
require 'thread'

module Cosmos

  # Defines all the attributes and methods common to all interface classes
  # used by COSMOS.
  class Interface
    include Api

    # @return [String] Name of the interface
    attr_reader :name

    # @return [Array<String>] Array of target names associated with this interface
    attr_accessor :target_names

    # @return [Thread] Thread reading from the interface
    attr_accessor :thread

    # @return [Boolean] Flag indicating if the interface should be connected
    #   to on startup
    attr_accessor :connect_on_startup

    # @return [Boolean] Flag indicating if the interface should automatically
    #   reconnect after losing connection
    attr_accessor :auto_reconnect

    # @return [Integer[ Delay between reconnect attempts
    attr_accessor :reconnect_delay

    # @return [Boolean] Flag indicating if the user is allowed to disconnect
    #   this interface
    attr_accessor :disable_disconnect

    # @return [Array] Array of packet logger classes for this interface
    attr_accessor :packet_log_writer_pairs

    # @return [RawLoggerPair] RawLoggerPair instance or nil
    attr_accessor :raw_logger_pair

    # @return [Array<Routers>] Array of routers that receive packets
    #   read from the interface
    attr_accessor :routers

    # @return [Array<Routers>] Array of cmd routers that mirror packets
    #   sent from the interface
    attr_accessor :cmd_routers

    # @return [Integer] The number of packets read from this interface
    attr_accessor :read_count

    # @return [Integer] The number of packets written to this interface
    attr_accessor :write_count

    # @return [Integer] The number of bytes read from this interface
    attr_accessor :bytes_read

    # @return [Integer] The number of bytes written to this interface
    attr_accessor :bytes_written

    # @return [Integer] The number of active clients
    #   (when used as a Router)
    attr_accessor :num_clients

    # @return [Integer] The number of packets in the read queue
    #   (when used as a Router)
    attr_accessor :read_queue_size

    # @return [Integer] The number of packets in the write queue
    #   (when used as a Router)
    attr_accessor :write_queue_size

    # @return [Array<Interface>] Array of interfaces to route packets to
    #   (when used as a Router)
    attr_accessor :interfaces

    # @return [Hash<option name, option values>] Hash of options supplied to interface/router
    attr_accessor :options

    # @return [Hash<protocol name, parameters>] Hash of parameters supplied to
    #   protocol
    attr_accessor :protocol_params

    # Initialize default attribute values
    def initialize
      @name = self.class.to_s.split("::")[-1] # Remove namespacing if present
      @target_names = []
      @thread = nil
      @connect_on_startup = true
      @auto_reconnect = true
      @reconnect_delay = 5.0
      @disable_disconnect = false
      @packet_log_writer_pairs = []
      @raw_logger_pair = RawLoggerPair.new(@name)
      @routers = []
      @cmd_routers = []
      @read_count = 0
      @write_count = 0
      @bytes_read = 0
      @bytes_written = 0
      @num_clients = 0
      @read_queue_size = 0
      @write_queue_size = 0
      @write_mutex = Mutex.new
      @interfaces = []
      @read_allowed = true
      @write_allowed = true
      @write_raw_allowed = true
      @options = {}
      @protocol_params = {}
    end

    # Connects the interface to its target(s). Must be implemented by a
    # subclass.
    def connect
    end

    # Indicates if the interface is connected to its target(s) or not. Must be
    # implemented by a subclass.
    def connected?
      false
    end

    # Disconnects the interface from its target(s). Must be implemented by a
    # subclass.
    def disconnect
    end

    # Retrieves the next packet from the interface.
    # @return [Packet] Packet constructed from the data. Packet will be
    #   unidentified (nil target and packet names)
    def read
      raise "Interface not connected for read: #{@name}" unless connected?
      data = read_data()
      return nil unless data
      @raw_logger_pair.read_logger.write(data) if @raw_logger_pair
      @bytes_read += data.length
      # data could be modified by post_read_data (bytes added or subtracted)
      # but we count the number of bytes read from the lowest level above
      data = post_read_data(data)
      return nil unless data
      packet = convert_data_to_packet(data)
      return nil unless packet
      packet = post_read_packet(packet)
      return nil unless packet
      @read_count += 1
      packet
    end

    # Method to send a packet on the interface.
    # @param packet [Packet] The Packet to send out the interface
    def write(packet)
      raise "Interface not connected for write: #{@name}" unless connected? && write_allowed?
      _write do
        packet = pre_write_packet(packet)
        next unless packet
        data = convert_packet_to_data(packet)
        next unless data
        data = pre_write_data(data)
        next unless data
        # Only bump the packet write count if we actually write out the data
        @write_count += 1
        data = write_data(data)
        post_write_data(packet, data)
        data
      end
    end

    # Writes preformatted data onto the interface. Malformed data may cause
    # problems.
    # @param data [String] The raw data to send out the interface
    def write_raw(data)
      raise "Interface not connected for write_raw : #{@name}" unless connected? && write_raw_allowed?
      _write do
        data = write_data(data)
        post_write_data(nil, data)
        data
      end
    end

    protected

    # Wrap all writes in a mutex and handle errors
    def _write
      @write_mutex.synchronize { yield }
    rescue Exception => err
      Logger.instance.error("Error writing to interface : #{@name}")
      disconnect()
      raise err
    end

    public

    # @return [Boolean] Whether reading is allowed
    def read_allowed?
      @read_allowed
    end

    # @return [Boolean] Whether writing is allowed
    def write_allowed?
      @write_allowed
    end

    # @return [Boolean] Whether writing raw data over the interface is allowed
    def write_raw_allowed?
      @write_raw_allowed
    end

    # Start raw logging for this interface
    def start_raw_logging
      @raw_logger_pair.start if @raw_logger_pair
    end

    # Stop raw logging for this interface
    def stop_raw_logging
      @raw_logger_pair.stop if @raw_logger_pair
    end

    # Set the interface name
    def name=(name)
      @name = name.to_s.clone
      @raw_logger_pair.name = name if @raw_logger_pair
    end

    # Copy settings from this interface to another interface. All instance
    # variables are copied except for thread, num_clients, read_queue_size,
    # and write_queue_size since these are all specific to the operation of the
    # interface rather than its instantiation.
    #
    # @param other_interface [Interface] The other interface to copy to
    def copy_to(other_interface)
      other_interface.name = name.clone
      other_interface.target_names = target_names.clone
      # The other interface has its own Thread
      other_interface.connect_on_startup = self.connect_on_startup
      other_interface.auto_reconnect = self.auto_reconnect
      other_interface.reconnect_delay = self.reconnect_delay
      other_interface.disable_disconnect = self.disable_disconnect
      other_interface.packet_log_writer_pairs = self.packet_log_writer_pairs.clone
      other_interface.routers = self.routers.clone
      other_interface.cmd_routers = self.cmd_routers.clone
      other_interface.read_count = self.read_count
      other_interface.write_count = self.write_count
      other_interface.bytes_read = self.bytes_read
      other_interface.bytes_written = self.bytes_written
      other_interface.raw_logger_pair = self.raw_logger_pair.clone if @raw_logger_pair
      # num_clients is per interface so don't copy
      # read_queue_size is the number of packets in the queue so don't copy
      # write_queue_size is the number of packets in the queue so don't copy
      other_interface.interfaces = interfaces.clone
      other_interface.options = options.clone
      other_interface.protocol_params = protocol_params.clone
    end

    # Set an interface or router specific option
    # @param option_name name of the option
    # @param option_values array of option values
    def set_option(option_name, option_values)
      @options[option_name.upcase] = option_values.clone
    end

    # Set procotol specific options
    # @param protocol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      @protocol_params[protocol] = params.clone
    end

    # Called to read data and manipulate it until enough data is
    # returned. The definition of 'enough data' changes depending on the
    # protocol used which is why this method exists. This method is also used
    # to perform operations on the data before it can be interpreted as packet
    # data such as decryption. After this method is called the post_read_data
    # method is called. Subclasses must implement this method.
    #
    # @return [String] Raw packet data
    def read_data
      nil
    end

    # Called to perform modifications on read data before making it into a packet.
    # After this method is called the post_read_packet method is called.
    #
    # @param data [String] Raw packet data
    # @return [String|nil] Potentially modified packet data or nil to abort read
    def post_read_data(data)
      data
    end

    # Called to convert the read data into a COSMOS Packet object
    #
    # @param data [String] Raw packet data
    # @return [Packet] COSMOS Packet with buffer filled with data
    def convert_data_to_packet(data)
      Packet.new(nil, nil, :BIG_ENDIAN, nil, data)
    end

    # Called to perform modifications on a read packet before it is identified
    # and inserted into the current value table. This is the final place to
    # modify data before it is used by the COSMOS system. An example would be
    # to set the packet timestamp. After this method is called the
    # post_identify_packet method is called.
    #
    # @param packet [Packet] Original packet
    # @return [Packet|nil] Potentially modified packet or nil to abort read
    def post_read_packet(packet)
      packet
    end

    # This method is called by the CmdTlmServer after each read packet is
    # identified. It can be used to perform custom processing/monitoring as
    # each packet is received by the CmdTlmServer.
    #
    # @param packet [Packet] The identified packet read from the interface
    def post_identify_packet(packet)
      nil
    end

    # Called to perform modifications on a command packet before it is turned
    # into packet data to send. An example would be to override a known packet
    # value. After this method is called the pre_write_data method is called.
    #
    # @param packet [Packet] Original packet
    # @return [Packet|nil] Potentially modified packet or nil to abort writing
    def pre_write_packet(packet)
      packet
    end

    # Called to convert a packet into the data to send
    #
    # @param packet [Packet] Packet to extract data from
    # @return data
    def convert_packet_to_data(packet)
      packet.buffer(false)
    end

    # Called to perform modifications on write data before writing it over the
    # interface.
    # After this method is called the post_write_data method is called.
    #
    # @param data [String] Raw packet data
    # @return [String|nil] Potentially modified data or nil to abort writing
    def pre_write_data(data)
      data
    end

    # Called to write data to the underlying interface. Subclasses must
    # implement this method and call super to count the raw bytes and allow raw
    # logging.
    #
    # @param data [String] Raw packet data
    # @return data [String] The exact data written
    def write_data(data)
      @bytes_written += data.length
      @raw_logger_pair.write_logger.write(data) if @raw_logger_pair
      data
    end

    # Called to perform actions after writing data to the interface. For
    # example if your interface expects an immediate telemetry response from a
    # previous command you can implement response processing. Nothing is called
    # after this method completes.
    #
    # @param packet [Packet] packet that was written out. Will be nil from write_raw
    # @param data [String] binary data that was written out
    def post_write_data(packet, data)
      # Default do nothing
    end

    # Handle Stream Protocol passed into COSMOS interface that use streams
    #
    # @param stream_protocol_type [String] Name of the Stream Protocol minus "StreamProtocol"
    # @param stream_protocol_args [Array] Array of arguments to pass to the stream_protocol
    def setup_stream_protocol(stream_protocol_type, stream_protocol_args)
      stream_protocol_class_name = stream_protocol_type.to_s.capitalize << 'StreamProtocol'
      klass = Cosmos.require_class(stream_protocol_class_name.class_name_to_filename)
      extend(klass)
      configure_protocol(stream_protocol_class_name, stream_protocol_args)
    end

  end
end
