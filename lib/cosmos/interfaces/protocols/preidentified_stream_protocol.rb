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
  module PreidentifiedStreamProtocol
    include StreamProtocol

    # Set procotol specific options
    # @param procotol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      super(protocol, params)
      configure_stream_protocol(*params) if protocol == 'PreidentifiedStreamProtocol'
    end

    # @param sync_pattern (see StreamProtocol#initialize)
    # @param max_length [Integer] The maximum allowed value of the length field
    def configure_stream_protocol(sync_pattern = nil, max_length = nil)
      super(0, sync_pattern)
      @max_length = ConfigParser.handle_nil(max_length)
      @max_length = Integer(@max_length) if @max_length
    end

    def post_read_packet(packet)
      packet.received_time = @received_time
      packet.target_name = @target_name
      packet.packet_name = @packet_name
      packet
    end

    def pre_write_packet(packet)
      received_time = packet.received_time
      received_time = Time.now unless received_time
      @time_seconds = [received_time.tv_sec].pack('N') # UINT32
      @time_microseconds = [received_time.tv_usec].pack('N') # UINT32
      @target_name = packet.target_name
      @target_name = 'UNKNOWN' unless @target_name
      @packet_name = packet.packet_name
      @packet_name = 'UNKNOWN' unless @packet_name
      packet
    end

    def pre_write_data(data)
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
      data_to_send
    end

    protected

    def read_length_field_followed_by_string(length_num_bytes)
      # Read bytes for string length
      read_minimum_size(length_num_bytes)
      return nil if @data.length <= 0
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
        return nil
      end

      # Read String
      read_minimum_size(string_length + length_num_bytes)
      return nil if @data.length <= 0
      next_index = string_length + length_num_bytes
      string = @data[length_num_bytes..(next_index - 1)]

      # Remove data from current_data
      @data.replace(@data[next_index..-1])

      string
    end

    def reduce_to_single_packet
      # Discard sync pattern if present
      @data.replace(@data[(@sync_pattern.length)..-1]) if @sync_pattern

      # Read and remove packet received time
      read_minimum_size(8)
      return nil if @data.length <= 0
      time_seconds = @data[0..3].unpack('N')[0] # UINT32
      time_microseconds = @data[4..7].unpack('N')[0] # UINT32
      @received_time = Time.at(time_seconds, time_microseconds).sys
      @data.replace(@data[8..-1])

      # Read and remove the target name
      @target_name = read_length_field_followed_by_string(1)
      return nil unless @target_name

      # Read and remove the packet name
      @packet_name = read_length_field_followed_by_string(1)
      return nil unless @packet_name

      # Read packet data and return
      read_length_field_followed_by_string(4)
    end
  end
end
