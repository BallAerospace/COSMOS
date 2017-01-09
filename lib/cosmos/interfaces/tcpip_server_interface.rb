# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'
require 'cosmos/io/tcpip_server'

module Cosmos

  # Base class for interfaces that act as a TCP/IP server
  class TcpipServerInterface < Interface
    extend Forwardable
    def_delegators :@tcpip_server, :connect, :connected?, :disconnect,
                   :num_clients, :read_queue_size, :write_queue_size,
                   :start_raw_logging, :stop_raw_logging

    # @param write_port [Integer] Port that clients should write commands to
    # @param read_port [Integer] Port that clients should read telemetry from
    # @param write_timeout [Integer] Seconds to wait before aborting writes
    # @param read_timeout [Integer] Seconds to wait before aborting reads
    # @param stream_protocol_type (see StreamInterface#initialize)
    # @param stream_protocol_args (see StreamInterface#initialize)
    def initialize(write_port,
                   read_port,
                   write_timeout,
                   read_timeout,
                   stream_protocol_type,
                   *stream_protocol_args)
      super()
      @tcpip_server = TcpipServer.new(write_port,
                                      read_port,
                                      write_timeout,
                                      read_timeout,
                                      stream_protocol_type,
                                      *stream_protocol_args)
      @tcpip_server.raw_logger_pair = @raw_logger_pair
      @read_allowed = false unless ConfigParser.handle_nil(read_port)
      @write_allowed = false unless ConfigParser.handle_nil(write_port)
      @write_raw_allowed = false unless ConfigParser.handle_nil(write_port)
    end

    # Calls tcpip_server read and turns the packet back into the raw data
    # buffer so it can be counted and processed by Interface read
    def read_data
      data = nil
      packet = @tcpip_server.read
      data = packet.buffer if packet
      data
    end

    # Writes the raw data to the tcpip_server
    # @param data [String] Raw data
    def write_data(data)
      @tcpip_server.write_raw(data)
      data
    end

    # Supported Options
    # LISTEN_ADDRESS - Ip address of the interface to accept connections on - Default: 0.0.0.0
    # (see Interface#set_option)
    def set_option(option_name, option_values)
      super(option_name, option_values)
      if option_name.casecmp('LISTEN_ADDRESS')
        @tcpip_server.listen_address = option_values[0]
      end
    end
  end
end
