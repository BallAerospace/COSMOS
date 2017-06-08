# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/api'
require 'cosmos/io/raw_logger_pair'

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

    # Initialize default attribute values
    def initialize
      @name = self.class.to_s
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
      @interfaces = []
      @read_allowed = true
      @write_allowed = true
      @write_raw_allowed = true
      @options = {}
    end

    # Connects the interface to its target(s). Must be implemented by a
    # subclass.
    def connect
      raise "Interface connect method not implemented"
    end

    # Indicates if the interface is connected to its target(s) or not. Must be
    # implemented by a subclass.
    def connected?
      raise "Interface connected? method not implemented"
    end

    # Disconnects the interface from its target(s). Must be implemented by a
    # subclass.
    def disconnect
      raise "Interface disconnect method not implemented"
    end

    # Retrieves the next packet from the interface. Must be implemented by a
    # subclass.
    def read
      raise "Interface read method not implemented"
    end

    # Method to send a packet on the interface. Must be implemented by a
    # subclass.
    def write(packet)
      raise "Interface write method not implemented"
    end

    # Writes preformatted data onto the interface. Malformed data may cause
    # problems. Must be implemented by a subclass.
    def write_raw(data)
      raise "Interface write_raw method not implemented"
    end

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
      other_interface.name = self.name.clone
      other_interface.target_names = self.target_names.clone
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
      other_interface.raw_logger_pair = self.raw_logger_pair.clone if self.raw_logger_pair
      # num_clients is per interface so don't copy
      # read_queue_size is the number of packets in the queue so don't copy
      # write_queue_size is the number of packets in the queue so don't copy
      other_interface.interfaces = self.interfaces.clone
      other_interface.options = self.options.clone
    end

    # Set an interface or router specific option
    # @param option_name name of the option
    # @param option_values array of option values
    def set_option(option_name, option_values)
      @options[option_name.upcase] = option_values.clone
    end

    # This method is called by the CmdTlmServer after each read packet is
    # identified. It can be used to perform custom processing/monitoring as
    # each packet is received by the CmdTlmServer.
    #
    # @param packet [Packet] The identified packet read from the interface
    def post_identify_packet(packet)
    end

  end # class Interface

end # module Cosmos
