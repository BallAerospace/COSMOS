# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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
require 'ipaddr'
require 'timeout' # for Timeout::Error

# Define needed constants for Windows
Socket::IP_MULTICAST_IF = 9 unless Socket.const_defined?('IP_MULTICAST_IF')
Socket::IP_MULTICAST_TTL = 10 unless Socket.const_defined?('IP_MULTICAST_TTL')

module Cosmos
  class UdpReadWriteSocket
    # @param bind_port [Integer[ Port to write data out from and receive data on (0 = randomly assigned)
    # @param bind_address [String] Local address to bind to (0.0.0.0 = All local addresses)
    # @param external_port [Integer] External port to write to
    # @param external_address [String] External host to send data to
    # @param multicast_interface_address [String] Local outgoing interface to send multicast packets from
    # @param ttl [Integer] Time To Live for outgoing multicast packets
    # @param read_multicast [Boolean] Whether or not to try to read from the external address as multicast
    # @param write_multicast [Boolean] Whether or not to write to the external address as multicast
    def initialize(
      bind_port = 0,
      bind_address = "0.0.0.0",
      external_port = nil,
      external_address = nil,
      multicast_interface_address = nil,
      ttl = 1,
      read_multicast = true,
      write_multicast = true
    )

      @socket = UDPSocket.new

      # Basic setup to reuse address
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

      # Bind to local address and port - This sets recv port, write_src port, recv_address, and write_src_address
      @socket.bind(bind_address, bind_port) if bind_address and bind_port

      # Default send to the specified address and port
      @socket.connect(external_address, external_port) if external_address and external_port

      # Handle multicast
      if UdpReadWriteSocket.multicast?(external_address, external_port)
        if write_multicast
          # Basic setup set time to live
          @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, ttl.to_i)

          # Set outgoing interface
          @socket.setsockopt(
            Socket::IPPROTO_IP,
            Socket::IP_MULTICAST_IF,
            IPAddr.new(multicast_interface_address).hton
          ) if multicast_interface_address
        end

        # Receive messages sent to the multicast address
        if read_multicast
          multicast_interface_address = "0.0.0.0" unless multicast_interface_address
          membership = IPAddr.new(external_address).hton + IPAddr.new(multicast_interface_address).hton
          @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
        end
      end
    end

    # @param data [String] Binary data to send
    # @param write_timeout [Float] Time in seconds to wait for the data to send
    def write(data, write_timeout = 10.0)
      num_bytes_to_send = data.length
      total_bytes_sent  = 0
      bytes_sent = 0
      data_to_send = data

      loop do
        begin
          bytes_sent = @socket.write_nonblock(data_to_send)
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          result = IO.fast_select(nil, [@socket], nil, write_timeout)
          if result
            retry
          else
            raise Timeout::Error, "Write Timeout"
          end
        end
        total_bytes_sent += bytes_sent
        break if total_bytes_sent >= num_bytes_to_send

        data_to_send = data[total_bytes_sent..-1]
      end
    end

    # @param read_timeout [Float] Time in seconds to wait for the read to
    #   complete
    def read(read_timeout = nil)
      data = nil
      begin
        data, _ = @socket.recvfrom_nonblock(65536)
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK
        result = IO.fast_select([@socket], nil, nil, read_timeout)
        if result
          retry
        else
          raise Timeout::Error, "Read Timeout"
        end
      end
      data
    end

    # Defer all methods to the UDPSocket
    def method_missing(method, *args, &block)
      @socket.__send__(method, *args, &block)
    end

    # @param host [String] Machine name or IP address
    # @param port [String] Port
    # @return [Boolean] Whether the hostname is multicast
    def self.multicast?(host, port)
      return false if host.nil? || port.nil?

      Addrinfo.udp(host, port).ipv4_multicast?
    end
  end

  # Creates a UDPSocket and implements a non-blocking write.
  class UdpWriteSocket < UdpReadWriteSocket
    # @param dest_address [String] Host to send data to
    # @param dest_port [Integer] Port to send data to
    # @param src_port [Integer[ Port to send data out from
    # @param multicast_interface_address [String] Local outgoing interface to send multicast packets from
    # @param ttl [Integer] Time To Live for outgoing packets
    # @param bind_address [String] Local address to bind to (0.0.0.0 = All local addresses)
    def initialize(
      dest_address,
      dest_port,
      src_port = nil,
      multicast_interface_address = nil,
      ttl = 1,
      bind_address = "0.0.0.0"
    )

      super(
        src_port,
        bind_address,
        dest_port,
        dest_address,
        multicast_interface_address,
        ttl,
        false,
        true)
    end
  end

  # Creates a UDPSocket and implements a non-blocking read.
  class UdpReadSocket < UdpReadWriteSocket
    # @param recv_port [Integer] Port to receive data on
    # @param multicast_address [String] Address to add multicast
    # @param multicast_interface_address [String] Local incoming interface to receive multicast packets on
    # @param bind_address [String] Local address to bind to (0.0.0.0 = All local addresses)
    def initialize(
      recv_port = 0,
      multicast_address = nil,
      multicast_interface_address = nil,
      bind_address = "0.0.0.0"
    )

      super(
        recv_port,
        bind_address,
        nil,
        multicast_address,
        multicast_interface_address,
        1,
        true,
        false)
    end
  end
end
