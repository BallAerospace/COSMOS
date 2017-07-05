# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/protocols/stream_protocol'

module Cosmos
  # This StreamProtocol delineates packets using the COSMOS preidentification system
  class PreidentifiedStreamProtocol < StreamProtocol

    # @param sync_pattern (see StreamProtocol#initialize)
    # @param max_length [Integer] The maximum allowed value of the length field
    def initialize(sync_pattern = nil, max_length = nil)
      super(0, sync_pattern)
      @max_length = ConfigParser.handle_nil(max_length)
      @max_length = Integer(@max_length) if @max_length
    end

    def reset
      super()
      @reduction_state = :START
    end

    def read_packet(packet)
      packet.received_time = @received_time
      packet.target_name = @target_name
      packet.packet_name = @packet_name
      return packet
    end

    def write_packet(packet)
      received_time = packet.received_time
      received_time = Time.now unless received_time
      @time_seconds = [received_time.tv_sec].pack('N') # UINT32
      @time_microseconds = [received_time.tv_usec].pack('N') # UINT32
      @target_name = packet.target_name
      @target_name = 'UNKNOWN' unless @target_name
      @packet_name = packet.packet_name
      @packet_name = 'UNKNOWN' unless @packet_name
      return packet
    end

    def write_data(data)
      data_length = [data.length].pack('N') # UINT32
      data_to_send = ''
      data_to_send << @sync_pattern if @sync_pattern
      data_to_send << @time_seconds
      data_to_send << @time_microseconds
      data_to_send << @target_name.length
      data_to_send << @target_name
      data_to_send << @packet_name.length
      data_to_send << @packet_name
      data_to_send << data_length
      data_to_send << data
      return data_to_send
    end

    protected

    def read_length_field_followed_by_string(length_num_bytes)
      # Read bytes for string length
      return :STOP if @data.length < length_num_bytes
      string_length = @data[0..(length_num_bytes - 1)]

      case length_num_bytes
      when 1
        string_length = string_length.unpack('C')[0] # UINT8
      when 2
        string_length = string_length.unpack('n')[0] # UINT16
      when 4
        string_length = string_length.unpack('N')[0] # UINT32
        raise "Length value received larger than max_length: #{string_length} > #{@max_length}" if @max_length and string_length > @max_length
      else
        raise "Unsupported length given to read_length_field_followed_by_string: #{length_num_bytes}"
      end

      # Read String
      return :STOP if @data.length < (string_length + length_num_bytes)
      next_index = string_length + length_num_bytes
      string = @data[length_num_bytes..(next_index - 1)]

      # Remove data from current_data
      @data.replace(@data[next_index..-1])

      return string
    end

    def reduce_to_single_packet
      # Discard sync pattern if present
      if @sync_pattern
        if @reduction_state == :START
          return :STOP if @data.length < @sync_pattern.length
          @data.replace(@data[(@sync_pattern.length)..-1])
          @reduction_state = :SYNC_REMOVED
        end
      elsif @reduction_state == :START
        @reduction_state = :SYNC_REMOVED
      end

      # Read and remove packet received time
      if @reduction_state == :SYNC_REMOVED
        return :STOP if @data.length < 8
        time_seconds = @data[0..3].unpack('N')[0] # UINT32
        time_microseconds = @data[4..7].unpack('N')[0] # UINT32
        @received_time = Time.at(time_seconds, time_microseconds).sys
        @data.replace(@data[8..-1])
        @reduction_state = :TIME_REMOVED
      end

      if @reduction_state == :TIME_REMOVED
        # Read and remove the target name
        @target_name = read_length_field_followed_by_string(1)
        return :STOP if @target_name == :STOP
        @reduction_state = :TARGET_NAME_REMOVED
      end

      if @reduction_state == :TARGET_NAME_REMOVED
        # Read and remove the packet name
        @packet_name = read_length_field_followed_by_string(1)
        return :STOP if @packet_name == :STOP
        @reduction_state = :PACKET_NAME_REMOVED
      end

      if @reduction_state == :PACKET_NAME_REMOVED
        # Read packet data and return
        packet_data = read_length_field_followed_by_string(4)
        return :STOP if packet_data == :STOP
        @reduction_state = :START
        return packet_data
      end

      raise "Error should never reach end of method #{@reduction_state}"
    end
  end
end
