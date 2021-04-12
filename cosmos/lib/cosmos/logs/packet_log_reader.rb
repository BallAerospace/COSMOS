# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/core_ext/io'
require 'cosmos/packets/packet'
require 'cosmos/packets/json_packet'
require 'cosmos/io/buffered_file'
require 'cosmos/logs/packet_log_constants'

module Cosmos
  # Reads a packet log of either commands or telemetry.
  class PacketLogReader
    include PacketLogConstants

    attr_reader :redis_offset

    MAX_READ_SIZE = 1000000000

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

      # seek_to_time(start_time) if start_time

      while true
        packet = read(identify_and_define)
        break unless packet

        time = packet.packet_time
        if time
          next if start_time and time < start_time
          break if end_time and time > end_time
        end

        yield packet
      end
    ensure
      close()
    end

    # @param filename [String] The log filename to open
    # @return [Boolean, Exception] Returns true if successfully changed to configuration specified in log,
    #    otherwise returns false and potentially an Exception class if an error occurred.  If no error occurred
    #    false indicates that the requested configuration was simply not found.
    def open(filename)
      close()
      reset()
      @filename = filename
      @file = BufferedFile.open(@filename, 'rb')
      @max_read_size = @file.size
      @max_read_size = MAX_READ_SIZE if @max_read_size > MAX_READ_SIZE
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
      # Read entry length
      length = @file.read(4)
      return nil if !length or length.length <= 0
      length = length.unpack('N')[0]
      entry = @file.read(length)
      flags = entry[0..1].unpack('n')[0]

      cmd_or_tlm = :TLM
      cmd_or_tlm = :CMD if flags & COSMOS5_CMD_FLAG_MASK == COSMOS5_CMD_FLAG_MASK
      stored = false
      stored = true if flags & COSMOS5_STORED_FLAG_MASK == COSMOS5_STORED_FLAG_MASK
      id = false
      id = true if flags & COSMOS5_ID_FLAG_MASK == COSMOS5_ID_FLAG_MASK

      if flags & COSMOS5_ENTRY_TYPE_MASK == COSMOS5_JSON_PACKET_ENTRY_TYPE_MASK
        packet_index, time_nsec_since_epoch = entry[2..11].unpack('nQ>')
        json_data = entry[12..-1]
        lookup_cmd_or_tlm, target_name, packet_name, id = @packets[packet_index]
        if cmd_or_tlm != lookup_cmd_or_tlm
          raise "Packet type mismatch, packet:#{cmd_or_tlm}, lookup:#{lookup_cmd_or_tlm}"
        end
        return JsonPacket.new(cmd_or_tlm, target_name, packet_name, time_nsec_since_epoch, stored, json_data)
      elsif flags & COSMOS5_ENTRY_TYPE_MASK == COSMOS5_RAW_PACKET_ENTRY_TYPE_MASK
        packet_index, time_nsec_since_epoch = entry[2..11].unpack('nQ>')
        packet_data = entry[12..-1]
        lookup_cmd_or_tlm, target_name, packet_name, id = @packets[packet_index]
        if cmd_or_tlm != lookup_cmd_or_tlm
          raise "Packet type mismatch, packet:#{cmd_or_tlm}, lookup:#{lookup_cmd_or_tlm}"
        end
        received_time = Time.from_nsec_from_epoch(time_nsec_since_epoch)
        if identify_and_define
          packet = identify_and_define_packet_data(cmd_or_tlm, target_name, packet_name, received_time, packet_data)
        else
          # Build Packet
          packet = Packet.new(target_name, packet_name, :BIG_ENDIAN, nil, packet_data)
        end
        packet.set_received_time_fast(received_time)
        packet.cmd_or_tlm = cmd_or_tlm
        packet.stored = stored
        packet.received_count += 1
        return packet
      elsif flags & COSMOS5_ENTRY_TYPE_MASK == COSMOS5_TARGET_DECLARATION_ENTRY_TYPE_MASK
        target_name_length = length - COSMOS5_PRIMARY_FIXED_SIZE - COSMOS5_TARGET_DECLARATION_SECONDARY_FIXED_SIZE
        target_name_length -= COSMOS5_ID_FIXED_SIZE if id
        target_name = entry[2..(target_name_length + 1)]
        if id
          id = entry[(target_name_length + 3)..(target_name_length + 34)]
          @target_ids << id
        end
        @target_names << target_name
        return read(identify_and_define)
      elsif flags & COSMOS5_ENTRY_TYPE_MASK == COSMOS5_PACKET_DECLARATION_ENTRY_TYPE_MASK
        target_index = entry[2..3].unpack('n')[0]
        target_name = @target_names[target_index]
        packet_name_length = length - COSMOS5_PRIMARY_FIXED_SIZE - COSMOS5_PACKET_DECLARATION_SECONDARY_FIXED_SIZE
        packet_name_length -= COSMOS5_ID_FIXED_SIZE if id
        packet_name = entry[4..(packet_name_length + 3)]
        if id
          id = entry[(packet_name_length + 4)..-1]
          @packet_ids << id
        end
        @packets << [cmd_or_tlm, target_name, packet_name, id]
        return read(identify_and_define)
      elsif flags & COSMOS5_ENTRY_TYPE_MASK == COSMOS5_OFFSET_MARKER_ENTRY_TYPE_MASK
        @redis_offset = entry[2..-1]
        return read(identify_and_define)
      else
        raise "Invalid Entry Flags: #{flags}"
      end
    rescue => err
      close()
      raise err
    end

    # TODO: Currently not used
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
    # def packet_offsets(filename, progress_callback = nil)
    #   open(filename)
    #   offsets = []
    #   filesize = size().to_f

    #   while true
    #     current_pos = @file.pos
    #     packet = read(false)
    #     break unless packet
    #     offsets << current_pos
    #     if progress_callback
    #       break if progress_callback.call(current_pos / filesize)
    #     end
    #   end

    #   return offsets
    # ensure
    #   close()
    # end

    # TODO: Currently not used
    # Reads a packet from the opened log file. Should only be used in
    # conjunction with {#packet_offsets}.
    #
    # @param file_offset [Integer] Byte offset into the log file to start
    #   reading
    # @param identify_and_define (see #each)
    # @return [Packet]
    # def read_at_offset(file_offset, identify_and_define = true)
    #   @file.seek(file_offset, IO::SEEK_SET)
    #   return read(identify_and_define)
    # rescue => err
    #   close()
    #   raise err
    # end

    # TODO: Currently not used
    # Read the first packet from the log file and reset the file position back
    # to the current position. This allows the client to call read multiple
    # times to return packets, call first, and continue calling read which will
    # return the next packet in the file.
    #
    # @return [Packet]
    # def first
    #   original_position = @file.pos
    #   @file.seek(0, IO::SEEK_SET)
    #   read_file_header()
    #   packet = read()
    #   raise "No first packet found" unless packet
    #   @file.seek(original_position, IO::SEEK_SET)
    #   packet.clone
    # rescue => err
    #   close()
    #   raise err
    # end

    # TODO: Currently not used
    # Read the last packet from the log file and reset the file position back
    # to the current position. This allows the client to call read multiple
    # times to return packets, call last, and continue calling read which will
    # return the next packet in the file.
    #
    # @return [Packet]
    # def last
    #   raise "TODO: Implement me - Need to add end of file entry to support"
    #   original_position = @file.pos
    #   @file.seek(-1, IO::SEEK_END)
    #   packet = search(-1)
    #   raise "No last packet found" unless packet
    #   @file.seek(original_position, IO::SEEK_SET)
    #   packet.clone
    # rescue => err
    #   close()
    #   raise err
    # end

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
      @max_read_size = MAX_READ_SIZE
      @target_names = []
      @target_ids = []
      @packets = []
      @packet_ids = []
      @redis_offset = nil
    end

    # This is best effort. May return unidentified/undefined packets
    def identify_and_define_packet_data(cmd_or_tlm, target_name, packet_name, received_time, packet_data)
      packet = nil
      unless target_name and packet_name
        if cmd_or_tlm == :CMD
          packet = System.commands.identify(packet_data)
        else
          packet = System.telemetry.identify!(packet_data)
        end
      else
        begin
          if cmd_or_tlm == :CMD
            packet = System.commands.packet(target_name, packet_name)
          else
            packet = System.telemetry.packet(target_name, packet_name)
          end
          packet.buffer = packet_data
        rescue
          # Could not find a definition for this packet
          Logger.instance.error "Unknown packet #{target_name} #{packet_name}"
          packet = Packet.new(target_name, packet_name, :BIG_ENDIAN, nil, packet_data)
        end
      end
      packet
    end

    # Should return if successfully switched to requested configuration
    def read_file_header
      header = @file.read(COSMOS5_HEADER_LENGTH)
      if header and header.length == COSMOS5_HEADER_LENGTH
        if header == COSMOS5_FILE_HEADER
          # Found COSMOS 5 File Header - That's all we need to do
        elsif header == COSMOS4_FILE_HEADER
          raise "COSMOS 4 log file must be converted to COSMOS 5"
        elsif header == COSMOS2_FILE_HEADER
          raise "COSMOS 2 log file must be converted to COSMOS 5"
        else
          raise "COSMOS file header not found"
        end
      else
        raise "Failed to read at least #{COSMOS5_HEADER_LENGTH} bytes from packet log"
      end
    end

    def seek_to_time(time)
      raise "TODO: Implement me - Use index file or offsets"
    end
  end
end
