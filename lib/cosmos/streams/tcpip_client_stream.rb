# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'socket'
require 'thread' # For Mutex
require 'timeout' # For Timeout::Error
require 'cosmos/streams/tcpip_socket_stream'
require 'cosmos/config/config_parser'

module Cosmos

  # Data {Stream} which reads and writes to TCPIP sockets. This class creates
  # the actual sockets based on the constructor parameters. The rest of the
  # interface is implemented by the super class {TcpipSocketStream}.
  class TcpipClientStream < TcpipSocketStream

    # @param hostname [String] The host to connect to
    # @param write_port [Integer|nil] The port to write. Pass nil to make this
    #   a read only stream.
    # @param read_port [Integer|nil] The port to read. Pass nil to make this
    #   a write only stream.
    # @param write_timeout (see TcpipSocketStream#initialize)
    # @param read_timeout (see TcpipSocketStream#initialize)
    def initialize(hostname, write_port, read_port, write_timeout, read_timeout)
      @hostname = hostname
      if (@hostname.to_s.upcase == 'LOCALHOST')
        @hostname = '127.0.0.1'
      end
      @write_port = ConfigParser.handle_nil(write_port)
      @write_port = Integer(write_port) if @write_port
      @read_port  = ConfigParser.handle_nil(read_port)
      @read_port  = Integer(read_port) if @read_port

      write_addr = nil
      read_addr = nil
      begin
        write_addr = Socket.pack_sockaddr_in(@write_port, @hostname) if @write_port
        read_addr  = Socket.pack_sockaddr_in(@read_port, @hostname) if @read_port
      rescue => error
        if error.message =~ /getaddrinfo/
          raise "Invalid hostname: #{@hostname}"
        else
          raise error
        end
      end

      write_socket = nil
      if write_addr
        write_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        write_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        write_socket.connect(write_addr)
      end

      read_socket = nil
      if read_addr
        if @write_port != @read_port
          read_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
          read_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          read_socket.connect(read_addr)
        else
          read_socket = write_socket
        end
      end

      super(write_socket, read_socket, write_timeout, read_timeout)
    end

  end # class TcpipClientStream

end # module Cosmos
