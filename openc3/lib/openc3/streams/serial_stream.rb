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

require 'thread' # For Mutex
require 'openc3/streams/stream'
require 'openc3/config/config_parser'
require 'openc3/io/serial_driver'

module OpenC3
  # Stream that reads and writes to serial ports by using {SerialDriver}.
  class SerialStream < Stream
    # @param write_port_name [String] The name of the serial port to write.
    #   Pass nil if the stream is to be read only. On Windows the port name
    #   is typically 'COMX' where X can be any port number. On UNIX the port
    #   name is typically a device such as '/dev/ttyS0'.
    # @param read_port_name [String] The name of the serial port to read.
    #   Pass nil if the stream is to be read only. On Windows the port name
    #   is typically 'COMX' where X can be any port number. On UNIX the port
    #   name is typically a device such as '/dev/ttyS0'.
    # @param baud_rate [Integer] The serial port baud rate
    # @param parity [Symbol] Must be :NONE, :EVEN, or :ODD
    # @param stop_bits [Integer] Number of stop bits. Must be 1 or 2.
    # @param write_timeout [Integer] Number of seconds to wait for the write to
    #   complete. Pass nil to create no timeout. The {SerialDriver} will
    #   continously try to send the data until it has been sent or an error
    #   occurs.
    # @param read_timeout [Integer] Number of seconds to wait for the read to
    #   complete. Pass nil to create no timeout. The {SerialDriver} will
    #   continously try to read data until it has received data or an error
    #   occurs.
    # @param flow_control [Symbol] Currently supported :NONE and :RTSCTS (default :NONE)
    # @param data_bits [Integer] Number of data bits (default 8)
    def initialize(write_port_name,
                   read_port_name,
                   baud_rate,
                   parity,
                   stop_bits,
                   write_timeout,
                   read_timeout,
                   flow_control = :NONE,
                   data_bits = 8)
      super()

      # The SerialDriver class will validate the parameters
      @write_port_name = ConfigParser.handle_nil(write_port_name)
      @read_port_name  = ConfigParser.handle_nil(read_port_name)
      @baud_rate       = Integer(baud_rate)
      @parity          = parity
      @stop_bits       = stop_bits.to_i
      @write_timeout   = ConfigParser.handle_nil(write_timeout)
      @write_timeout   = @write_timeout.to_f if @write_timeout
      @read_timeout    = ConfigParser.handle_nil(read_timeout)
      @read_timeout    = @read_timeout.to_f if @read_timeout
      @flow_control    = flow_control.to_s.intern
      @data_bits       = data_bits.to_i

      if @write_port_name
        @write_serial_port = SerialDriver.new(@write_port_name,
                                              @baud_rate,
                                              @parity,
                                              @stop_bits,
                                              @write_timeout,
                                              @read_timeout,
                                              @flow_control,
                                              @data_bits)
      else
        @write_serial_port = nil
      end
      if @read_port_name
        if @read_port_name == @write_port_name
          @read_serial_port = @write_serial_port
        else
          @read_serial_port = SerialDriver.new(@read_port_name,
                                               @baud_rate,
                                               @parity,
                                               @stop_bits,
                                               @write_timeout,
                                               @read_timeout,
                                               @flow_control,
                                               @data_bits)
        end
      else
        @read_serial_port = nil
      end
      if @read_serial_port.nil? && @write_serial_port.nil?
        raise "Either a write port or read port must be given"
      end

      # We 'connect' when we create the stream
      @connected = true

      # Mutex on write is needed to protect from commands coming in from more
      # than one tool
      @write_mutex = Mutex.new
    end

    # @return [String] Returns a binary string of data from the serial port
    def read
      raise "Attempt to read from write only stream" unless @read_serial_port

      # No read mutex is needed because reads happen serially
      @read_serial_port.read
    end

    # @return [String] Returns a binary string of data from the serial port without blocking
    def read_nonblock
      raise "Attempt to read from write only stream" unless @read_serial_port

      # No read mutex is needed because reads happen serially
      @read_serial_port.read_nonblock
    end

    # @param data [String] A binary string of data to write to the serial port
    def write(data)
      raise "Attempt to write to read only stream" unless @write_serial_port

      @write_mutex.synchronize do
        @write_serial_port.write(data)
      end
    end

    # Connect the stream
    def connect
      # N/A - Serial streams 'connect' on creation
    end

    # @return [Boolean] Whether the serial stream is connected to the serial
    #   port
    def connected?
      @connected
    end

    # Disconnect by closing the serial ports
    def disconnect
      if @connected
        begin
          @write_serial_port.close if @write_serial_port && !@write_serial_port.closed?
        rescue IOError
          # Ignore
        end

        begin
          @read_serial_port.close if @read_serial_port && !@read_serial_port.closed?
        rescue IOError
          # Ignore
        end
        @connected = false
      end
    end
  end # class SerialStream
end
