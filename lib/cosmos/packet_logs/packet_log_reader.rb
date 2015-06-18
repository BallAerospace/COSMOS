# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/core_ext/io'
require 'cosmos/packets/packet'
require 'cosmos/io/buffered_file'

module Cosmos

  # Reads a packet log of either commands or telemetry.
  class PacketLogReader
    attr_reader :log_type
    attr_reader :configuration_name
    attr_reader :hostname

    # COSMOS 2.0 log file header definition
    COSMOS2_MARKER = 'COSMOS2_'
    COSMOS2_HEADER_LENGTH = 128
    COSMOS2_MARKER_RANGE = 0..7
    COSMOS2_LOG_TYPE_RANGE = 8..10
    COSMOS2_CONFIGURATION_NAME_RANGE = 12..43
    COSMOS2_HOSTNAME_RANGE = 45..127

    # COSMOS 1.0 log file header definition
    COSMOS1_MARKER = 'COSMOS'
    COSMOS1_HEADER_LENGTH = 42
    COSMOS1_MARKER_RANGE = 0..5
    COSMOS1_LOG_TYPE_RANGE = 6..8
    COSMOS1_CONFIGURATION_NAME_RANGE = 10..41

    # Create a new log file reader
    def initialize
      reset()
    end

    # Yields back each packet as it is found in the log file.
    #
    # @param filename [String] The log file to read
    # @param identify_and_define [Boolean] Once the packet has been read from
    #   the log file, whether to both identify the packet by setting the target
    #   and packet name, and define the packet by populating all the items.
    # @param start_time [Time|nil] Time at which to start returning packets.
    #   Packets found with a timestamp before this time are ignored. Pass nil
    #   to return all packets.
    # @param end_time [Time|nil] Time at which to stop returning packets.
    #   Packets found with a timestamp after this time are ignored. Pass nil
    #   to return all packets.
    # @yieldparam packet [Packet]
    def each(filename, identify_and_define = true, start_time = nil, end_time = nil)
      open(filename)

      seek_to_time(start_time) if start_time

      while true
        packet = read(identify_and_define)
        break unless packet

        received_time = packet.received_time
        if received_time
          next if start_time and received_time < start_time
          break if end_time and received_time > end_time
        end

        yield packet
      end
    ensure
      close()
    end

    # Returns an analysis of the log file by reading all the packets and
    # returning information about each packet. This information maps directly
    # to the parameters need by the {#read_at_offset} method and thus should be
    # called before using {#read_at_offset}.
    #
    # @param filename [String] The filename to analyze
    # @param progress_callback [Proc] Callback that should receive a single
    #   floating point parameter which is the percentage done
    # @return [Array<Array<Integer, Integer, String, String, Time, Time>] Array
    #   of arrays for each packet found in the log file consisting of:
    #   [File position, length, target name, packet name, time formatted,
    #   received time].
    def packet_offsets(filename, progress_callback = nil)
      open(filename)
      offsets = []
      filesize = size().to_f

      while true
        current_pos = @file.pos
        packet = read(false)
        break unless packet
        offsets << current_pos
        if progress_callback
          break if progress_callback.call(current_pos / filesize)
        end
      end

      return offsets
    ensure
      close()
    end

    # @param filename [String] The log filename to open
    # @return [Boolean, Exception] Returns true if successfully changed to configuration specified in log,
    #    otherwise returns false and potentially an Exception class if an error occurred.  If no error occurred
    #    false indicates that the requested configuration was simply not found
    def open(filename)
      close()
      reset()
      @filename = filename
      @file = BufferedFile.open(@filename, 'rb')
      @bytes_read = 0
      return read_file_header()
    rescue => err
      close()
      raise err
    end

    # Closes the current log file
    def close
      @file.close if @file and !@file.closed?
    end

    # Read a packet from the log file
    #
    # @param identify_and_define (see #each)
    # @return [Packet]
    def read(identify_and_define = true)
      # Read the Packet Header
      success, target_name, packet_name, received_time = read_entry_header()
      return nil unless success

      # Read Packet Data
      packet_data = @file.read_length_bytes(4)
      return nil unless packet_data and packet_data.length > 0

      if identify_and_define
        packet = identify_and_define_packet_data(target_name, packet_name, received_time, packet_data)
      else
        # Build Packet
        packet = Packet.new(target_name, packet_name, :BIG_ENDIAN, nil, packet_data)
        packet.set_received_time_fast(received_time)
      end

      packet
    rescue => err
      close()
      raise err
    end

    # Reads a packet from the opened log file. Should only be used in
    # conjunction with {#packet_offsets}.
    #
    # @param file_offset [Integer] Byte offset into the log file to start
    #   reading
    # @param identify_and_define (see #each)
    # @return [Packet]
    def read_at_offset(file_offset, identify_and_define = true)
      @file.seek(file_offset, IO::SEEK_SET)
      return read(identify_and_define)
    rescue => err
      close()
      raise err
    end

    # Read the first packet from the log file and reset the file position back
    # to the current position. This allows the client to call read multiple
    # times to return packets, call first, and continue calling read which will
    # return the next packet in the file.
    #
    # @return [Packet]
    def first
      original_position = @file.pos
      @file.seek(0, IO::SEEK_SET)
      read_file_header()
      packet = read()
      raise "No first packet found" unless packet
      @file.seek(original_position, IO::SEEK_SET)
      packet.clone
    rescue => err
      close()
      raise err
    end

    # Read the last packet from the log file and reset the file position back
    # to the current position. This allows the client to call read multiple
    # times to return packets, call last, and continue calling read which will
    # return the next packet in the file.
    #
    # @return [Packet]
    def last
      original_position = @file.pos
      @file.seek(-1, IO::SEEK_END)
      packet = search(-1)
      raise "No last packet found" unless packet
      @file.seek(original_position, IO::SEEK_SET)
      packet.clone
    rescue => err
      close()
      raise err
    end

    # @return [Integer] The size of the log file being processed
    def size
      @file.stat.size
    end

    # @return [Integer] The current file position in the log file
    def bytes_read
      @file.pos
    end

    protected

    def reset
      @file = nil
      @filename = nil
      @log_type = :TLM
      @configuration_name = nil
      @hostname = nil
      @file_header_length = COSMOS2_HEADER_LENGTH
    end

    # This is best effort. May return unidentified/undefined packets
    def identify_and_define_packet_data(target_name, packet_name, received_time, packet_data)
      packet = nil
      unless (target_name and packet_name)
        if @log_type == :TLM
          packet = System.telemetry.identify!(packet_data)
        else
          packet = System.commands.identify(packet_data)
        end
        packet.set_received_time_fast(received_time) if packet
      else
        begin
          if @log_type == :TLM
            packet = System.telemetry.packet(target_name, packet_name)
          else
            packet = System.commands.packet(target_name, packet_name)
          end
          packet.buffer = packet_data
          packet.set_received_time_fast(received_time)
        rescue
          # Could not find a definition for this packet
          Logger.instance.error "Unknown packet #{target_name} #{packet_name}"
          packet = Packet.new(target_name, packet_name, :BIG_ENDIAN, nil, packet_data)
          packet.set_received_time_fast(received_time)
        end
      end
      packet
    end

    # Should return if successfully switched to requested configuration
    def read_file_header
      header = @file.read(COSMOS2_HEADER_LENGTH)
      if header and header.length == COSMOS2_HEADER_LENGTH
        if header[COSMOS2_MARKER_RANGE] == COSMOS2_MARKER
          # Found COSMOS 2 File Header
          @log_type = header[COSMOS2_LOG_TYPE_RANGE].intern
          raise "Unknown log type #{@log_type}" unless [:CMD, :TLM].include? @log_type
          @configuration_name = header[COSMOS2_CONFIGURATION_NAME_RANGE]
          @hostname = header[COSMOS2_HOSTNAME_RANGE].strip
          @file_header_length = COSMOS2_HEADER_LENGTH
          new_config_name, error = System.load_configuration(@configuration_name)
          return true, error if new_config_name == @configuration_name
          return false, error # Did not successfully change to requested configuration name
        elsif header[COSMOS1_MARKER_RANGE] == COSMOS1_MARKER
          # Found COSMOS 1 File Header
          @log_type = header[COSMOS1_LOG_TYPE_RANGE].upcase.intern
          raise "Unknown log type #{@log_type}" unless [:CMD, :TLM].include? @log_type
          @configuration_name = header[COSMOS1_CONFIGURATION_NAME_RANGE]
          @hostname = nil
          @file_header_length = COSMOS1_HEADER_LENGTH
          # Move back to beginning of first packet
          @file.seek(COSMOS1_HEADER_LENGTH, IO::SEEK_SET)
          new_config_name, error = System.load_configuration(@configuration_name)
          return true, error if new_config_name == @configuration_name
          return false, error # Did not successfully change to requested configuration name
        else
          raise "COSMOS file header not found on packet log"
        end
      else
        raise "Failed to read at least #{COSMOS2_HEADER_LENGTH} bytes from packet log"
      end
    end

    def read_entry_header
      # Read Received Time
      time_seconds = @file.read(4)
      return [nil, nil, nil, nil] if time_seconds.nil? or time_seconds.length != 4
      time_seconds = time_seconds.unpack('N')[0]
      time_microseconds = @file.read(4)
      return [nil, nil, nil, nil] if time_microseconds.nil? or time_microseconds.length != 4
      time_microseconds = time_microseconds.unpack('N')[0]
      received_time = Time.at(time_seconds, time_microseconds)

      # Read Target Name
      target_name = @file.read_length_bytes(1)
      return [nil, nil, nil, nil] unless target_name and target_name.length > 0

      # Read Packet Name
      packet_name = @file.read_length_bytes(1)
      return [nil, nil, nil, nil] unless packet_name and packet_name.length > 0

      return [true, target_name, packet_name, received_time]
    end

    def test
      found = false

      # Save original position
      original_position = @file.pos

      begin
        # Try to read the packet header
        # This will fail with file read errors and invalid timestamps
        success, target_name, packet_name, _ = read_entry_header()
        if success
          if target_name !~ File::NON_ASCII_PRINTABLE and packet_name !~ File::NON_ASCII_PRINTABLE
            packet_data_length = @file.read(4)
            if packet_data_length.length == 4 and packet_data_length.unpack('N')[0] > 0
              if @log_type == :TLM
                if System.telemetry.packet(target_name, packet_name)
                  found = true
                end
              else
                if System.commands.packet(target_name, packet_name)
                  found = true
                end
              end
            end
          end
        end
      rescue
        # Packet not found
      end

      # Return to the original position
      @file.seek(original_position, IO::SEEK_SET)

      # Indicate if a packet was found
      found
    end

    # Searchs for the nearest packet to the current io position
    # Returns the packet if found, and leaves the io position
    # either before or after the packet found
    def search(offset_increment, leave_position = :AFTER)
      position = @file.pos
      @file.seek(0, IO::SEEK_END)
      size = @file.pos
      @file.seek(position, IO::SEEK_SET)

      while (@file.pos > 0 and @file.pos < size)
        if test()
          # Save position
          position = @file.pos

          packet = read()

          if packet
            if leave_position != :AFTER
              # Restore position
              @file.seek(position, IO::SEEK_SET)
            end

            return packet
          end

          # Restore position
          @file.seek(position, IO::SEEK_SET)
        end
        @file.seek(offset_increment, IO::SEEK_CUR)
      end

      # Return nil if we search beyond the size of the file
      nil
    end

    def seek_to_time(time)
      if time
        position = @file.pos

        begin
          # Read the first packet in the log
          first_packet = first()
          raise "Error reading first packet" unless first
          raise "First Packet does not contain a packet received time" unless first_packet.received_time

          # Read the last packet in the log
          file_size = size()
          last_packet = last()
          raise "Search failed looking for last packet" unless last_packet
          raise "Last Packet does not contain a packet received time" unless last_packet.received_time

          if time >= first_packet.received_time and time <= last_packet.received_time
            # Guess at where to start looking for time in log
            percentage = (time - first_packet.received_time) / (last_packet.received_time - first_packet.received_time)
            offset = (percentage * file_size.to_f).to_i
            offset = @file_header_length if offset < @file_header_length
            @file.seek(offset, IO::SEEK_SET)

            # Move backwards until a packet before the time is found
            while true
              packet = search(-1, :BEFORE)
              break if !packet or packet.received_time <= time

              # Guess again
              percentage = 1.0 - ((packet.received_time - time) / (packet.received_time - first_packet.received_time))
              offset = (percentage * @file.pos.to_f).to_i
              offset = @file_header_length if offset < @file_header_length
              @file.seek(offset, IO::SEEK_SET)
            end

            # Move forwards until a packet equal to or after the time is found
            while true
              position = @file.pos
              packet = read(false)
              raise "Search failed looking for packet after time" unless packet
              if packet.received_time >= time
                # Back up this packet so the read can get it because we want it
                @file.seek(position, IO::SEEK_SET)
                break
              end
            end

          else
            if time > last_packet.received_time
              # File is entirely before time, so jump to the end
              @file.seek(0, IO::SEEK_END)
            else
              raise "File does not include time"
            end
          end
        rescue # Optimized search failed or not supported
          # Restore position
          @file.seek(position, IO::SEEK_SET)
        end
      end
    end

  end # class PacketLogReader

end # module Cosmos
