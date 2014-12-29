# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'socket'
require 'ipaddr'
require 'timeout' # for Timeout::Error

# Define needed constants for Windows
Socket::IP_MULTICAST_IF = 9 unless Socket.const_defined?('IP_MULTICAST_IF')
Socket::IP_MULTICAST_TTL = 10 unless Socket.const_defined?('IP_MULTICAST_TTL')

module Cosmos

  # Creates a UDPSocket and implements a non-blocking write.
  class UdpWriteSocket

    # @param dest_address [String] Host to send data to
    # @param dest_port [Integer] Port to send data to
    # @param src_port [Integer[ Port to send data out from
    # @param interface_address [String] Local outgoing interface to send from
    # @param ttl [Integer] Time To Live for outgoing packets
    def initialize(dest_address,
                   dest_port,
                   src_port = nil,
                   interface_address = nil,
                   ttl = 1,
                   bind_address = "0.0.0.0")
      @socket = UDPSocket.new

      # Basic setup to reuse address
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

      # Set source port if given
      @socket.bind(bind_address, src_port) if src_port

      # Default send to the specified address and port
      @socket.connect(dest_address, dest_port)

      # Handle multicast
      if UdpWriteSocket.multicast?(dest_address)
        # Basic setup set time to live
        @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, ttl.to_i)

        # Set outgoing interface
        @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, IPAddr.new(interface_address).hton) if interface_address
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

    # Defer all methods to the UDPSocket
    def method_missing(method, *args, &block)
      @socket.__send__(method, *args, &block)
    end

    # @param host [String] Machine name or IP address
    # @return [Boolean] Whether the hostname is multicast
    def self.multicast?(host)
      return false if host.nil?
      # Look up address
      _, _, _, *address_list = Socket.gethostbyname(host)
      first_addr_byte = 0
      address_list.each do |address|
        if address.length == 4
          first_addr_byte = address.getbyte(0)
          break
        end
      end

      if (first_addr_byte >= 224) && (first_addr_byte <= 239)
        true
      else
        false
      end
    end
  end

  # Creates a UDPSocket and implements a non-blocking read.
  class UdpReadSocket

    # @param recv_port [Integer] Port to receive data on
    # @param multicast_address [String] Address to add multicast
    def initialize(recv_port = 0, multicast_address = nil, interface_address = nil, bind_address = "0.0.0.0")
      @socket = UDPSocket.new

      # Basic setup to reuse address
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

      # bind to port
      @socket.bind(bind_address, recv_port)

      if UdpWriteSocket.multicast?(multicast_address)
        interface_address = "0.0.0.0" unless interface_address
        membership = IPAddr.new(multicast_address).hton + IPAddr.new(interface_address).hton
        @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
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
  end

end # module Cosmos
