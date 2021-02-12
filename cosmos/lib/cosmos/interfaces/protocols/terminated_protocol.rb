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

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/burst_protocol'

module Cosmos
  # Protocol which delineates packets using termination characters at
  # the end of the data.
  class TerminatedProtocol < BurstProtocol
    # @param write_termination_characters [String] The characters to write
    #   after writing the Packet buffer. Must be given as a
    #   hexadecimal string such as '0xABCD'.
    # @param read_termination_characters [String] The characters at the end of
    #   the data which delineate the end of a Packet. Must be given as a
    #   hexadecimal string such as '0xABCD'.
    # @param strip_read_termination [Boolean] Whether to remove the
    #   read_termination_characters before turning the data into a
    #   Packet.
    # @param discard_leading_bytes (see BurstProtocol#initialize)
    # @param sync_pattern (see BurstProtocol#initialize)
    # @param fill_fields (see BurstProtocol#initialize)
    # @param allow_empty_data [true/false/nil] See Protocol#initialize
    def initialize(
      write_termination_characters,
      read_termination_characters,
      strip_read_termination = true,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      fill_fields = false,
      allow_empty_data = nil
    )
      @write_termination_characters = write_termination_characters.hex_to_byte_string
      @read_termination_characters = read_termination_characters.hex_to_byte_string
      @strip_read_termination = ConfigParser.handle_true_false(strip_read_termination)

      super(discard_leading_bytes, sync_pattern, fill_fields, allow_empty_data)
    end

    def write_data(data)
      raise "Packet contains termination characters!" if data.index(@write_termination_characters)
      data = super(data)
      @write_termination_characters.each_byte do |byte|
        data << byte
      end
      return data
    end

    protected
    def reduce_to_single_packet
      index = @data.index(@read_termination_characters)

      # Reduce to packet data and setup current_data for next packet
      if index
        if index > 0
          if @strip_read_termination
            packet_data = @data[0..(index - 1)]
          else
            packet_data = @data[0..(index + @read_termination_characters.length - 1)]
          end
        else # @data begins with the termination characters
          if @strip_read_termination
            packet_data = ''
          else # Keep everything
            packet_data = @data[0..(@read_termination_characters.length - 1)]
          end
        end
        @data.replace(@data[(index + @read_termination_characters.length)..-1])
        return packet_data
      else
        return :STOP
      end
    end
  end
end
