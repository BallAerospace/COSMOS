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
      @tcpip_server.interface = self
      @read_allowed = false unless ConfigParser.handle_nil(read_port)
      @write_allowed = false unless ConfigParser.handle_nil(write_port)
      @write_raw_allowed = false unless ConfigParser.handle_nil(write_port)
    end

    # (see TcpipServer#connect)
    def connect
      @tcpip_server.raw_logger_pair = @raw_logger_pair
      @tcpip_server.connect
    end

    # (see TcpipServer#connected?)
    def connected?
      @tcpip_server.connected?
    end

    # (see TcpipServer#disconnect)
    def disconnect
      @tcpip_server.disconnect
    end

    # (see TcpipServer#read)
    def read
      # Normal case will not be trying to read if not connected so don't bother checking
      packet = @tcpip_server.read
      @read_count += 1 if packet
      packet
    end

    # If the server has connections, the packet is written to all the connected
    # clients.
    #
    # @param packet [Packet]
    def write(packet)
      if connected?()
        begin
          @tcpip_server.write(packet)
          @write_count += 1
        rescue Exception => err
          Logger.instance.error("Error writing to interface : #{@name}")
          disconnect()
          raise err
        end
      else
        raise "Interface not connected for write : #{@name}"
      end
    end

    # If the server has connections, the data is written to all the connected
    # clients.
    #
    # @param data [String] Raw binary data
    def write_raw(data)
      if connected?()
        begin
          @tcpip_server.write_raw(data)
          @write_count += 1
        rescue Exception => err
          Logger.instance.error("Error writing raw data to interface : #{@name}")
          disconnect()
          raise err
        end
      else
        raise "Interface not connected for write_raw : #{@name}"
      end
    end

    # (see TcpipServer#bytes_read)
    def bytes_read
      @tcpip_server.bytes_read
    end

    # (see TcpipServer#bytes_read)
    def bytes_read=(bytes_read)
      @tcpip_server.bytes_read = bytes_read
    end

    # (see TcpipServer#bytes_written)
    def bytes_written
      @tcpip_server.bytes_written
    end

    # (see TcpipServer#bytes_written)
    def bytes_written=(bytes_written)
      @tcpip_server.bytes_written = bytes_written
    end

    # Number of clients connected to the TCP/IP server
    def num_clients
      @tcpip_server.num_clients
    end

    # Number of packets buffered in the read queue
    def read_queue_size
      @tcpip_server.read_queue_size
    end

    # Number of packets buffered in the write queue
    def write_queue_size
      @tcpip_server.write_queue_size
    end

    # Start raw logging for this interface
    def start_raw_logging
      @tcpip_server.start_raw_logging
    end

    # Stop raw logging for this interface
    def stop_raw_logging
      @tcpip_server.stop_raw_logging
    end

    # Supported Options
    # LISTEN_ADDRESS - Ip address of the interface to accept connections on - Default: 0.0.0.0
    # (see Interface#set_option)
    def set_option(option_name, option_values)
      super(option_name, option_values)
      if option_name.upcase == 'LISTEN_ADDRESS'
        @tcpip_server.listen_address = option_values[0]
      end
    end

  end # class TcpipServerInterface

end # module Cosmos
