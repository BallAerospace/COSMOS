# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/win32/win32'
require 'timeout' # For Timeout::Error

module Cosmos

  # Serial driver for use on Windows serial ports
  class Win32SerialDriver

    # (see SerialDriver#initialize)
    def initialize(port_name = 'COM1',
                   baud_rate = 9600,
                   parity = :NONE,
                   stop_bits = 1,
                   write_timeout = 10.0,
                   read_timeout = nil,
                   read_polling_period = 0.01,
                   read_max_length = 1000)

      # Verify Parameters
      port_name = '\\\\.\\' + port_name if port_name =~ /^COM[0-9]{2,3}$/

      raise(ArgumentError, "Invalid baud rate: #{baud_rate}") unless Win32::BAUD_RATES.include?(baud_rate)

      raise(ArgumentError, "Invalid parity: #{parity}") if parity and !SerialDriver::VALID_PARITY.include?(parity)
      case parity
      when SerialDriver::ODD
        parity = Win32::ODDPARITY
      when SerialDriver::EVEN
        parity = Win32::EVENPARITY
      when SerialDriver::NONE
        parity = Win32::NOPARITY
      end

      raise(ArgumentError, "Invalid stop bits: #{stop_bits}") unless [1,2].include?(stop_bits)
      if stop_bits == 1
        stop_bits = Win32::ONESTOPBIT
      else
        stop_bits = Win32::TWOSTOPBITS
      end

      @write_timeout = write_timeout
      @read_timeout = read_timeout
      @read_polling_period = read_polling_period
      @read_max_length = read_max_length

      # Open the Comm Port
      @handle = Win32.create_file(port_name,
                                  Win32::GENERIC_READ | Win32::GENERIC_WRITE,
                                  0,
                                  Win32::NULL,
                                  Win32::OPEN_EXISTING,
                                  Win32::FILE_ATTRIBUTE_NORMAL)

      # Configure the Comm Port
      dcb = Win32.get_comm_state(@handle)
      dcb.write('BaudRate', baud_rate)
      dcb.write('ByteSize', 8)
      dcb.write('Parity',   parity)
      dcb.write('StopBits', stop_bits)
      Win32.set_comm_state(@handle, dcb)

      # Configure Timeouts
      Win32.set_comm_timeouts(@handle, 4294967295, 0, 0, 0, 0)
    end

    # (see SerialDriver#close)
    def close
      if @handle
        # Close the Comm Port
        Win32.close_handle(@handle)
        @handle = nil
      end
    end

    # (see SerialDriver#closed?)
    def closed?
      if @handle
        false
      else
        true
      end
    end

    # (see SerialDriver#write)
    def write(data)
      # Write the data
      time = Time.now
      bytes_to_write = data.length
      while (bytes_to_write > 0)
        bytes_written = Win32.write_file(@handle, data, data.length)
        raise "Error writing to comm port" if bytes_written <= 0
        bytes_to_write -= bytes_written
        data = data[bytes_written..-1]
        raise Timeout::Error, "Write Timeout" if @write_timeout and (Time.now - time > @write_timeout) and bytes_to_write > 0
      end
    end

    # (see SerialDriver#read)
    def read
      data = ''
      sleep_time = 0.0

      loop do
        loop do
          # Read 1 byte
          buffer = Win32.read_file(@handle, 1)
          data << buffer
          break if buffer.length <= 0 or data.length >= @read_max_length
        end
        break if data.length > 0
        if @read_timeout and sleep_time >= @read_timeout
          raise Timeout::Error, "Read Timeout"
        end
        sleep(@read_polling_period)
        sleep_time += @read_polling_period
      end

      data
    end

    # (see SerialDriver#read_nonblock)
    def read_nonblock
      data = ''

      loop do
        # Read 1 byte
        buffer = Win32.read_file(@handle, 1)
        data << buffer
        break if buffer.length <= 0 or data.length >= @read_max_length
      end

      data
    end

  end # class Win32SerialDriver

end # module Cosmos
