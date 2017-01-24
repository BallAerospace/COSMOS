# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'
require 'cosmos/streams/tcpip_client_stream'

module Cosmos
  # Base class for interfaces that act as a TCP/IP client
  class TcpipClientInterface < Interface

    # @param hostname [String] Machine to connect to
    # @param write_port [Integer] Port to write commands to
    # @param read_port [Integer] Port to read telemetry from
    # @param write_timeout [Integer] Seconds to wait before aborting writes
    # @param read_timeout [Integer] Seconds to wait before aborting reads
    # @param stream_protocol_type [String] Name of the stream protocol to use
    #   with this interface
    # @param stream_protocol_args [Array<String>] Arguments to pass to the protocol
    def initialize(hostname,
                   write_port,
                   read_port,
                   write_timeout,
                   read_timeout,
                   stream_protocol_type,
                   *stream_protocol_args)
      super()
      stream_protocol_class = stream_protocol_type.to_s.capitalize << 'StreamProtocol'
      begin
        # Initially try to find the class directly in the path
        require stream_protocol_class.class_name_to_filename
        klass = Cosmos.require_class(stream_protocol_class.class_name_to_filename)
      rescue LoadError => error
        # Try to load the class from the known COSMOS protocols path location
        klass = Cosmos.require_class("cosmos/interfaces/protocols/#{stream_protocol_class.class_name_to_filename}")
      end
      extend(klass)
      configure_stream_protocol(*stream_protocol_args)

      @hostname = hostname
      @write_port = ConfigParser.handle_nil(write_port)
      @read_port = ConfigParser.handle_nil(read_port)
      @write_timeout = write_timeout
      @read_timeout = read_timeout
      @read_allowed = false unless @read_port
      @write_allowed = false unless @write_port
      @write_raw_allowed = false unless @write_port
    end

    # Connects the {TcpipClientStream} by passing the
    # initialization parameters to the {TcpipClientStream}.
    def connect
      super()
      @stream = TcpipClientStream.new(@hostname,
                                      @write_port,
                                      @read_port,
                                      @write_timeout,
                                      @read_timeout)
    end
  end
end
