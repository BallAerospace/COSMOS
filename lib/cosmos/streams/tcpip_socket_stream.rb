# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'socket'
require 'thread' # For Mutex
require 'timeout' # For Timeout::Error
require 'cosmos/streams/stream'
require 'cosmos/config/config_parser'

module Cosmos

  # Data {Stream} which reads and writes from Tcpip Sockets.
  class TcpipSocketStream < Stream
    attr_reader :write_socket

    # @param write_socket [Socket] Socket to write
    # @param read_socket [Socket] Socket to read
    # @param write_timeout [Float|nil] Number of seconds to wait for the write
    #   to complete or nil to block until the socket is ready to write.
    # @param read_timeout [Float|nil] Number of seconds to wait for the read
    #   to complete or nil to block until the socket is ready to read.
    def initialize(write_socket, read_socket, write_timeout, read_timeout)
      super()

      @write_socket  = write_socket
      @read_socket   = read_socket
      @write_timeout = ConfigParser.handle_nil(write_timeout)
      @write_timeout = @write_timeout.to_f if @write_timeout
      @read_timeout  = ConfigParser.handle_nil(read_timeout)
      @read_timeout  = @read_timeout.to_f if @read_timeout

      # Mutex on write is needed to protect from commands coming in from more
      # than one tool
      @write_mutex = Mutex.new
      @connected = false
    end

    # @return [String] Returns a binary string of data from the socket
    def read
      raise "Attempt to read from write only stream" unless @read_socket

      # No read mutex is needed because there is only one stream procesor
      # reading
      begin
        data = @read_socket.recv_nonblock(65535)
        @raw_logger_pair.read_logger.write(data) if @raw_logger_pair
      rescue IO::WaitReadable
        # Wait for the socket to be ready for reading or for the timeout
        begin
          result = IO.fast_select([@read_socket], nil, nil, @read_timeout)

          # If select returns something it means the socket is now available for
          # reading so retry the read. If it returns nil it means we timed out.
          if result
            retry
          else
            raise Timeout::Error, "Read Timeout"
          end
        rescue IOError, Errno::ENOTSOCK
          # These can happen with the socket being closed while waiting on select
          data = ''
        end
      rescue Errno::ECONNRESET, Errno::ECONNABORTED, IOError, Errno::ENOTSOCK
        data = ''
      end

      data
    end

    # @return [String] Returns a binary string of data from the socket. Always returns immediately
    def read_nonblock
      # No read mutex is needed because there is only one stream procesor
      # reading
      begin
        data = @read_socket.recv_nonblock(65535)
        @raw_logger_pair.read_logger.write(data) if @raw_logger_pair
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::ECONNRESET, Errno::ECONNABORTED
        data = ''
      end

      data
    end

    # @param data [String] A binary string of data to write to the socket
    def write(data)
      raise "Attempt to write to read only stream" unless @write_socket

      @write_mutex.synchronize do
        num_bytes_to_send = data.length
        total_bytes_sent = 0
        bytes_sent = 0
        data_to_send = data

        loop do
          begin
            bytes_sent = @write_socket.write_nonblock(data_to_send)
            @raw_logger_pair.write_logger.write(data_to_send[0..(bytes_sent - 1)]) if @raw_logger_pair and bytes_sent > 0
          rescue Errno::EAGAIN, Errno::EWOULDBLOCK
            # Wait for the socket to be ready for writing or for the timeout
            result = IO.fast_select(nil, [@write_socket], nil, @write_timeout)
            # If select returns something it means the socket is now available for
            # writing so retry the write. If it returns nil it means we timed out.
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
    end

    # Connect the stream
    def connect
      # If called directly this class is acting as a server and does not need to connect the sockets
      @connected = true
    end

    # @return [Boolean] Whether the sockets are connected
    def connected?
      @connected
    end

    # Disconnect by closing the sockets
    def disconnect
      Cosmos.close_socket(@write_socket)
      Cosmos.close_socket(@read_socket)
      @connected = false
    end

  end # class TcpipSocketStream

end # module Cosmos
