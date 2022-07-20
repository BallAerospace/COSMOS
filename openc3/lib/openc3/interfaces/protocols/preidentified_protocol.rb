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

require 'openc3/interfaces/protocols/burst_protocol'

module OpenC3
  # Delineates packets using the OpenC3 preidentification system
  class PreidentifiedProtocol < BurstProtocol
    COSMOS4_STORED_FLAG_MASK = 0x80
    COSMOS4_EXTRA_FLAG_MASK = 0x40

    # @param sync_pattern (see BurstProtocol#initialize)
    # @param max_length [Integer] The maximum allowed value of the length field
    # @param allow_empty_data [true/false/nil] See Protocol#initialize
    def initialize(sync_pattern = nil, max_length = nil, mode = 4, allow_empty_data = nil)
      super(0, sync_pattern, false, allow_empty_data)
      @max_length = ConfigParser.handle_nil(max_length)
      @max_length = Integer(@max_length) if @max_length
      @mode = Integer(mode)
    end

    def reset
      super()
      @reduction_state = :START
    end

    def read_packet(packet)
      packet.received_time = @read_received_time
      packet.target_name = @read_target_name
      packet.packet_name = @read_packet_name
      if @mode == 4 # COSMOS4.3+ Protocol
        packet.stored = @read_stored
        packet.extra = @read_extra
      end
      return packet
    end

    def write_packet(packet)
      received_time = packet.received_time
      received_time = Time.now unless received_time
      @write_time_seconds = [received_time.tv_sec].pack('N') # UINT32
      @write_time_microseconds = [received_time.tv_usec].pack('N') # UINT32
      @write_target_name = packet.target_name
      @write_target_name = 'UNKNOWN' unless @write_target_name
      @write_packet_name = packet.packet_name
      @write_packet_name = 'UNKNOWN' unless @write_packet_name
      if @mode == 4 # COSMOS4.3+ Protocol
        @write_flags = 0
        @write_flags |= COSMOS4_STORED_FLAG_MASK if packet.stored
        @write_extra = nil
        if packet.extra
          @write_flags |= COSMOS4_EXTRA_FLAG_MASK
          @write_extra = packet.extra.as_json(:allow_nan => true).to_json(:allow_nan => true)
        end
      end
      return packet
    end

    def write_data(data)
      data_length = [data.length].pack('N') # UINT32
      data_to_send = ''
      data_to_send << @sync_pattern if @sync_pattern
      if @mode == 4 # COSMOS4.3+ Protocol
        data_to_send << @write_flags
        if @write_extra
          data_to_send << [@write_extra.length].pack('N')
          data_to_send << @write_extra
        end
      end
      data_to_send << @write_time_seconds
      data_to_send << @write_time_microseconds
      data_to_send << @write_target_name.length
      data_to_send << @write_target_name
      data_to_send << @write_packet_name.length
      data_to_send << @write_packet_name
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

      if @reduction_state == :SYNC_REMOVED and @mode == 4
        # Read and remove flags
        return :STOP if @data.length < 1

        flags = @data[0].unpack('C')[0] # byte
        @data.replace(@data[1..-1])
        @read_stored = false
        @read_stored = true if (flags & COSMOS4_STORED_FLAG_MASK) != 0
        @read_extra = nil
        if (flags & COSMOS4_EXTRA_FLAG_MASK) != 0
          @reduction_state = :NEED_EXTRA
        else
          @reduction_state = :FLAGS_REMOVED
        end
      end

      if @reduction_state == :NEED_EXTRA
        # Read and remove extra
        @read_extra = read_length_field_followed_by_string(4)
        return :STOP if @read_extra == :STOP

        @read_extra = JSON.parse(@read_extra, :allow_nan => true, :create_additions => true)
        @reduction_state = :FLAGS_REMOVED
      end

      if @reduction_state == :FLAGS_REMOVED or (@reduction_state == :SYNC_REMOVED and @mode != 4)
        # Read and remove packet received time
        return :STOP if @data.length < 8

        time_seconds = @data[0..3].unpack('N')[0] # UINT32
        time_microseconds = @data[4..7].unpack('N')[0] # UINT32
        @read_received_time = Time.at(time_seconds, time_microseconds).sys
        @data.replace(@data[8..-1])
        @reduction_state = :TIME_REMOVED
      end

      if @reduction_state == :TIME_REMOVED
        # Read and remove the target name
        @read_target_name = read_length_field_followed_by_string(1)
        return :STOP if @read_target_name == :STOP

        @reduction_state = :TARGET_NAME_REMOVED
      end

      if @reduction_state == :TARGET_NAME_REMOVED
        # Read and remove the packet name
        @read_packet_name = read_length_field_followed_by_string(1)
        return :STOP if @read_packet_name == :STOP

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
