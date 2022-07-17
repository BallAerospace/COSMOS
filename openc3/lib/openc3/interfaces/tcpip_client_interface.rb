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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/interfaces/stream_interface'
require 'openc3/streams/tcpip_client_stream'

module OpenC3
  # Base class for interfaces that act as a TCP/IP client
  class TcpipClientInterface < StreamInterface
    # @param hostname [String] Machine to connect to
    # @param write_port [Integer] Port to write commands to
    # @param read_port [Integer] Port to read telemetry from
    # @param write_timeout [Integer] Seconds to wait before aborting writes
    # @param read_timeout [Integer] Seconds to wait before aborting reads
    # @param protocol_type [String] Name of the protocol to use
    #   with this interface
    # @param protocol_args [Array<String>] Arguments to pass to the protocol
    def initialize(
      hostname,
      write_port,
      read_port,
      write_timeout,
      read_timeout,
      protocol_type = nil,
      *protocol_args
    )

      super(protocol_type, protocol_args)

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
      @stream = TcpipClientStream.new(
        @hostname,
        @write_port,
        @read_port,
        @write_timeout,
        @read_timeout
      )
      super()
    end
  end
end
