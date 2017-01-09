# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/streams/serial_stream'

module Cosmos

  # Provides a base class for interfaces that use serial ports
  class SerialInterface < Interface

    # Creates a serial interface which uses the specified stream protocol.
    #
    # @param write_port_name [String] The name of the serial port to write
    # @param read_port_name [String] The name of the serial port to read
    # @param baud_rate [Integer] The serial port baud rate
    # @param parity [Symbol] The parity which is normally :NONE.
    #   Must be one of :NONE, :EVEN, or :ODD.
    # @param stop_bits [Integer] The number of stop bits which is normally 1.
    # @param write_timeout [Integer] The number of seconds to attempt the write
    #   before aborting
    # @param read_timeout [Integer] The number of seconds to attempt to read
    #   data from the serial port before aborting
    # @param stream_protocol_type [String] Combined with 'StreamProtocol'
    #   this should resolve to a COSMOS stream protocol class
    # @param stream_protocol_args [Array] Arguments to pass to the stream
    #   protocol class constructor
    def initialize(write_port_name,
                   read_port_name,
                   baud_rate,
                   parity,
                   stop_bits,
                   write_timeout,
                   read_timeout,
                   stream_protocol_type,
                   *stream_protocol_args)
      super(stream_protocol_type, *stream_protocol_args)

      @write_port_name = ConfigParser.handle_nil(write_port_name)
      @read_port_name  = ConfigParser.handle_nil(read_port_name)
      @baud_rate = baud_rate
      @parity = parity.to_s.intern
      @stop_bits = stop_bits
      @write_timeout = write_timeout
      @read_timeout = read_timeout

      @write_allowed     = false unless @write_port_name
      @write_raw_allowed = false unless @write_port_name
      @read_allowed      = false unless @read_port_name
    end

    # Connects the stream protocol to a new {SerialStream} using the
    # parameters passed in the constructor.
    def connect
      @stream = SerialStream.new(
        @write_port_name,
        @read_port_name,
        @baud_rate,
        @parity,
        @stop_bits,
        @write_timeout,
        @read_timeout
      )
      @stream.raw_logger_pair = @raw_logger_pair
      @stream.connect
    end
  end
end
