# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
                   read_max_length = 1000,
                   flow_control = :NONE,
                   data_bits = 8)

      # Verify Parameters
      port_name = '\\\\.\\' + port_name if port_name =~ /^COM[0-9]{2,3}$/

      raise(ArgumentError, "Invalid baud rate: #{baud_rate}") unless baud_rate.between?(Win32::BAUD_RATES[0], Win32::BAUD_RATES[-1])
      raise(ArgumentError, "Invalid data bits: #{data_bits}") unless [5,6,7,8].include?(data_bits)
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
      @mutex = Mutex.new

      # Configure the Comm Port - See: https://msdn.microsoft.com/en-us/library/windows/desktop/aa363214(v=vs.85).aspx
      dcb = Win32.get_comm_state(@handle)
      dcb.write('BaudRate', baud_rate)
      dcb.write('ByteSize', data_bits)
      dcb.write('Parity',   parity)
      dcb.write('StopBits', stop_bits)
      if flow_control == :RTSCTS
        # Monitor CTS
        dcb.write('fOutxCtsFlow', 1)

        # 0x00 - RTS_CONTROL_DISABLE - Disables the RTS line when the device is opened and leaves it disabled.
        # 0x01 - RTS_CONTROL_ENABLE - Enables the RTS line when the device is opened and leaves it on.
        # 0x02 - RTS_CONTROL_HANDSHAKE - Enables RTS handshaking. The driver raises the RTS line when the "type-ahead" (input) buffer is less than one-half full and lowers the RTS line when the buffer is more than three-quarters full. If handshaking is enabled, it is an error for the application to adjust the line by using the EscapeCommFunction function.
        # 0x03 - RTS_CONTROL_TOGGLE - Specifies that the RTS line will be high if bytes are available for transmission. After all buffered bytes have been sent, the RTS line will be low.
        dcb.write('fRtsControl', 0x03)
      end
      Win32.set_comm_state(@handle, dcb)

      # Configure Timeouts, the WinAPI structure is COMMTIMEOUTS:
      #   DWORD ReadIntervalTimeout;
      #   DWORD ReadTotalTimeoutMultiplier;
      #   DWORD ReadTotalTimeoutConstant;
      #   DWORD WriteTotalTimeoutMultiplier;
      #   DWORD WriteTotalTimeoutConstant;
      # 0xFFFFFFFF, 0, 0 specifies that the read operation is to return immediately
      # with the bytes that have already been received, even if no bytes have been received.
      # The WriteTotalTimeoutMultiplier is multiplied by the number of bytes to be written
      # and the WriteTotalTimeoutConstant is added to that total (both are in milliseconds).
      bits_per_symbol = data_bits + 1 # 1 start bit
      case stop_bits
      when Win32::ONESTOPBIT
        bits_per_symbol += 1
      when Win32::TWOSTOPBITS
        bits_per_symbol += 2
      end
      case parity
      when Win32::ODDPARITY, Win32::EVENPARITY
        bits_per_symbol += 1
      end
      delay = (1000.0 / (baud_rate / bits_per_symbol.to_f)).ceil
      Win32.set_comm_timeouts(@handle, 0xFFFFFFFF, 0, 0, delay, 1000)
    end

    # (see SerialDriver#close)
    def close
      if @handle
        # Close the Comm Port
        Win32.close_handle(@handle)
        @mutex.synchronize do
          @handle = nil
        end
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
      time = Time.now.sys
      bytes_to_write = data.length
      while (bytes_to_write > 0)
        bytes_written = Win32.write_file(@handle, data, data.length)
        raise "Error writing to comm port" if bytes_written <= 0
        bytes_to_write -= bytes_written
        data = data[bytes_written..-1]
        raise Timeout::Error, "Write Timeout" if @write_timeout and (Time.now.sys - time > @write_timeout) and bytes_to_write > 0
      end
    end

    # (see SerialDriver#read)
    def read
      data = ''
      sleep_time = 0.0

      loop do
        loop do
          buffer = nil
          @mutex.synchronize do
            break unless @handle
            buffer = Win32.read_file(@handle, @read_max_length - data.length)
          end
          break unless buffer
          data << buffer
          break if buffer.length <= 0 or data.length >= @read_max_length or !@handle
        end
        break if data.length > 0 or !@handle
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
        buffer = Win32.read_file(@handle, @read_max_length - data.length)
        data << buffer
        break if buffer.length <= 0 or data.length >= @read_max_length
      end
      data
    end
  end
end
