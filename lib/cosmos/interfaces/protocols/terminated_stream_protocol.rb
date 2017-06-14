# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/interfaces/protocols/stream_protocol'

module Cosmos
  # Protocol which delineates packets using termination characters at
  # the end of the stream.
  module TerminatedStreamProtocol
    include StreamProtocol

    # Set procotol specific options
    # @param procotol [String] Name of the procotol
    # @param params [Array<Object>] Array of parameter values
    def configure_protocol(protocol, params)
      super(protocol, params)
      configure_stream_protocol(*params) if protocol == 'TerminatedStreamProtocol'
    end

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
    # @param fill_fields (see StreamProtocol#initialize)
    def configure_stream_protocol(
      write_termination_characters,
      read_termination_characters,
      strip_read_termination = true,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      fill_fields = false
    )
      @write_termination_characters = write_termination_characters.hex_to_byte_string
      @read_termination_characters = read_termination_characters.hex_to_byte_string
      @strip_read_termination = ConfigParser.handle_true_false(strip_read_termination)

      super(discard_leading_bytes, sync_pattern, fill_fields)
    end

    # See StreamProtocol#pre_write_data
    def pre_write_data(data)
      raise "Packet contains termination characters!" if data.index(@write_termination_characters)
      data = super(data)
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
          if index > 0
            if @strip_read_termination
              packet_data = @data[0..(index - 1)]
            else
              packet_data = @data[0..(index + @read_termination_characters.length - 1)]
            end
          else
            packet_data = ''
          end
          @data.replace(@data[(index + @read_termination_characters.length)..-1])
          return packet_data
        else
          read_and_handle_timeout()
          return nil if @data.length <= 0
        end
      end
    end
  end
end
