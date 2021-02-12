# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

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
    def initialize(hostname, write_port, read_port, write_timeout, read_timeout, connect_timeout = 5.0)
      @hostname = hostname
      if (@hostname.to_s.upcase == 'LOCALHOST')
        @hostname = '127.0.0.1'
      end
      @write_port = ConfigParser.handle_nil(write_port)
      @write_port = Integer(write_port) if @write_port
      @read_port  = ConfigParser.handle_nil(read_port)
      @read_port  = Integer(read_port) if @read_port

      @write_addr = nil
      @read_addr = nil
      begin
        @write_addr = Socket.pack_sockaddr_in(@write_port, @hostname) if @write_port
        @read_addr = Socket.pack_sockaddr_in(@read_port, @hostname) if @read_port
      rescue => error
        if error.message =~ /getaddrinfo/
          raise "Invalid hostname: #{@hostname}"
        else
          raise error
        end
      end

      write_socket = nil
      if @write_addr
        write_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        write_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      end

      read_socket = nil
      if @read_addr
        if @write_port != @read_port
          read_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
          read_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        else
          read_socket = write_socket
        end
      end

      @connect_timeout = ConfigParser.handle_nil(connect_timeout)
      @connect_timeout = @connect_timeout.to_f if @connect_timeout

      super(write_socket, read_socket, write_timeout, read_timeout)
    end

    # Connect the socket(s)
    def connect
      connect_nonblock(@write_socket, @write_addr) if @write_socket
      connect_nonblock(@read_socket, @read_addr) if @read_socket and @read_socket != @write_socket
      super()
    end

    protected

    def connect_nonblock(socket, addr)
      begin
        socket.connect_nonblock(addr)
      rescue IO::WaitWritable
        begin
          _, sockets, _ = IO.select(nil, [socket], nil, @connect_timeout) # wait 3-way handshake completion
        rescue IOError, Errno::ENOTSOCK
          raise "Connect canceled"
        end
        if sockets and !sockets.empty?
          begin
            socket.connect_nonblock(addr) # check connection failure
          rescue IOError, Errno::ENOTSOCK
            raise "Connect canceled"
          rescue Errno::EINPROGRESS
            retry
          rescue Errno::EISCONN, Errno::EALREADY
          end
        else
          raise "Connect timeout"
        end
      rescue IOError, Errno::ENOTSOCK
        raise "Connect canceled"
      end
    end

  end # class TcpipClientStream

end # module Cosmos
