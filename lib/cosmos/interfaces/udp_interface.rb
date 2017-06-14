# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'
require 'cosmos/io/udp_sockets'
require 'cosmos/config/config_parser'

module Cosmos
  # Base class for interfaces that send and receive messages over UDP
  class UdpInterface < Interface
    # @param hostname [String] Machine to connect to
    # @param write_dest_port [Integer] Port to write commands to
    # @param read_port [Integer] Port to read telemetry from
    # @param write_src_port [Integer] Port to allow replies if needed
    # @param interface_address [String] If the destination machine represented
    #   by hostname supports multicast, then interface_address is used to
    #   configure the outgoing multicast address.
    # @param ttl [Integer] Time To Live value. The number of intermediate
    #   routers allowed before dropping the packet.
    # @param write_timeout [Integer] Seconds to wait before aborting writes
    # @param read_timeout [Integer] Seconds to wait before aborting reads
    # @param bind_address [String] Address to bind UDP ports to
    def initialize(
      hostname,
      write_dest_port,
      read_port,
      write_src_port = nil,
      interface_address = nil,
      ttl = 128, # default for Windows
      write_timeout = 10.0,
      read_timeout = nil,
      bind_address = '0.0.0.0')

      super()
      @hostname = ConfigParser.handle_nil(hostname)
      if @hostname
        @hostname = @hostname.to_s
        @hostname = '127.0.0.1' if @hostname.casecmp('LOCALHOST')
      end
      @write_dest_port = ConfigParser.handle_nil(write_dest_port)
      @write_dest_port = write_dest_port.to_i if @write_dest_port
      @read_port = ConfigParser.handle_nil(read_port)
      @read_port = read_port.to_i if @read_port
      @write_src_port = ConfigParser.handle_nil(write_src_port)
      @write_src_port = @write_src_port.to_i if @write_src_port
      @interface_address = ConfigParser.handle_nil(interface_address)
      if @interface_address && @interface_address.casecmp('LOCALHOST')
        @interface_address = '127.0.0.1'
      end
      @ttl = ttl.to_i
      @ttl = 1 if @ttl < 1
      @write_timeout = ConfigParser.handle_nil(write_timeout)
      @write_timeout = @write_timeout.to_f if @write_timeout
      @read_timeout = ConfigParser.handle_nil(read_timeout)
      @read_timeout = @read_timeout.to_f if @read_timeout
      @bind_address = ConfigParser.handle_nil(bind_address)
      if @bind_address && @bind_address.casecmp('LOCALHOST')
        @bind_address = '127.0.0.1'
      end
      @write_socket = nil
      @read_socket = nil
      @read_allowed = false unless @read_port
      @write_allowed = false unless @write_dest_port
      @write_raw_allowed = false unless @write_dest_port
    end

    # Creates a new {UdpWriteSocket} if the the write_dest_port was given in
    # the constructor and a new {UdpReadSocket} if the read_port was given in
    # the constructor.
    def connect
      @write_socket = UdpWriteSocket.new(
        @hostname,
        @write_dest_port,
        @write_src_port,
        @interface_address,
        @ttl,
        @bind_address) if @write_dest_port
      @read_socket = UdpReadSocket.new(
        @read_port,
        @hostname,
        @interface_address,
        @bind_address) if @read_port
      @thread_sleeper = nil
    end

    # @return [Boolean] Whether the active ports (read and/or write) have
    #   created sockets. Since UDP is connectionless, creation of the sockets
    #   is used to determine connection.
    def connected?
      if @write_dest_port && @read_port
        (@write_socket && @read_socket) ? true : false
      elsif @write_dest_port
        @write_socket ? true : false
      else
        @read_socket ? true : false
      end
    end

    # Close the active ports (read and/or write) and set the sockets to nil.
    def disconnect
      Cosmos.close_socket(@write_socket)
      @write_socket = nil
      Cosmos.close_socket(@read_socket)
      @read_socket = nil
      @thread_sleeper.cancel if @thread_sleeper
      @thread_sleeper = nil
    end

    # Reads from the socket if the read_port is defined
    def read_data
      if @read_port
        @read_socket.read(@read_timeout)
      else
        # Write only interface so stop the thread which calls read
        @thread_sleeper = Sleeper.new
        @thread_sleeper.sleep(1_000_000_000) while connected?
        nil
      end
    rescue IOError # Disconnected
      return nil
    end

    # Writes to the socket
    # @param data [String] Raw packet data
    def write_data(data)
      super(data)
      @write_socket.write(data, @write_timeout)
      data
    end
  end
end
