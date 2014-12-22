# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/streams/stream_protocol'

module Cosmos

  # This StreamProtocol delineates packets using termination characters at
  # the end of the stream.
  class TerminatedStreamProtocol < StreamProtocol

    # @param write_termination_characters [String] The characters to write to
    #   the stream after writing the Packet buffer. Must be given as a
    #   hexadecimal string such as '0xABCD'.
    # @param read_termination_characters [String] The characters at the end of
    #   the stream which delineate the end of a Packet. Must be given as a
    #   hexadecimal string such as '0xABCD'.
    # @param strip_read_termination [Boolean] Whether to remove the
    #   read_termination_characters before turning the stream data into a
    #   Packet.
    # @param discard_leading_bytes (see StreamProtocol#initialize)
    # @param sync_pattern (see StreamProtocol#initialize)
    # @param fill_sync_pattern (see StreamProtocol#initialize)
    def initialize(write_termination_characters,
                   read_termination_characters,
                   strip_read_termination = true,
                   discard_leading_bytes = 0,
                   sync_pattern = nil,
                   fill_sync_pattern = false)
      @write_termination_characters = write_termination_characters.hex_to_byte_string
      @read_termination_characters  = read_termination_characters.hex_to_byte_string
      @strip_read_termination       = ConfigParser.handle_true_false(strip_read_termination)

      super(discard_leading_bytes, sync_pattern, fill_sync_pattern)
    end

    # See StreamProtocol#pre_write_packet
    def pre_write_packet(packet)
      data = super(packet)
      raise "Packet contains termination characters!" if data.index(@write_termination_characters)

      data = data.clone # Don't want to modify the actual packet buffer with the termination characters
      @write_termination_characters.each_byte do |byte|
        data << byte
      end
      data
    end

    protected

    def reduce_to_single_packet
      while true
        index = @data.index(@read_termination_characters)

        # Reduce to packet data and setup current_data for next packet
        if index
          if @strip_read_termination
            packet_data = @data[0..(index - 1)]
          else
            packet_data = @data[0..(index + @read_termination_characters.length - 1)]
          end
          @data.replace(@data[(index + @read_termination_characters.length)..-1])
          return packet_data
        else
          read_and_handle_timeout()
          return nil if @data.length <= 0
        end
      end
    end

  end # class TerminatedStreamProtocol

end # module Cosmos
