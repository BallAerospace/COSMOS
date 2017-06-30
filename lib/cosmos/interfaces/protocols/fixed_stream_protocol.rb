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

  # This StreamProtocol delineates packets by identifying them and then
  # reading out their entire fixed length. Packets lengths can vary but
  # they must all be fixed.
  class FixedStreamProtocol < StreamProtocol
    # @param min_id_size [Integer] The minimum amount of data needed to
    #   identify a packet.
    # @param discard_leading_bytes (see StreamProtocol#initialize)
    # @param sync_pattern (see StreamProtocol#initialize)
    # @param telemetry_stream [Boolean] Whether the stream is returning
    #   telemetry (true) or commands (false)
    # @param fill_fields (see StreamProtocol#initialize)
    def initialize(
      min_id_size,
      discard_leading_bytes = 0,
      sync_pattern = nil,
      telemetry_stream = true,
      fill_fields = false,
      unknown_raise = false
    )
      super(discard_leading_bytes, sync_pattern, fill_fields)
      @min_id_size = Integer(min_id_size)
      @telemetry_stream = telemetry_stream
      @unknown_raise = ConfigParser::handle_true_false(unknown_raise)
    end

    # Set the received_time, target_name and packet_name which we recorded when
    # we identified this packet. The server will also do this but since we know
    # the information here, we perform this optimization.
    # See StreamProtocol#post_read_packet
    def read_packet(packet)
      packet.received_time = @received_time
      packet.target_name = @target_name
      packet.packet_name = @packet_name
      return packet
    end

    protected

    # Identifies an unknown buffer of data as a Packet. The raw data is
    # returned but the packet that matched is recorded so it can be set in the
    # post_read_packet callback.
    #
    # @return [String|nil] The identified packet data or nil if the stream was
    #   closed
    def identify_and_finish_packet
      packet_data = nil
      identified_packet = nil

      @interface.target_names.each do |target_name|
        target_packets = nil
        begin
          if @telemetry_stream
            target_packets = System.telemetry.packets(target_name)
          else
            target_packets = System.commands.packets(target_name)
          end
        rescue RuntimeError
          # No telemetry for this target
          next
        end

        target_packets.each do |packet_name, packet|
          if (packet.identify?(@data))
            identified_packet = packet
            if identified_packet.defined_length > @data.length
              # Check if need more data to finish packet
              return :STOP if @data.length < identified_packet.defined_length
            end
            # Set some variables so we can update the packet in
            # post_read_packet
            @received_time = Time.now.sys
            @target_name = identified_packet.target_name
            @packet_name = identified_packet.packet_name

            # Get the data from this packet
            packet_data = @data[0..(identified_packet.defined_length - 1)]
            @data.replace(@data[identified_packet.defined_length..-1])
            break
          end
        end
        break if identified_packet
      end

      unless identified_packet
        raise "Unknown data received by FixedStreamProtocol" if unknown_raise
        # Unknown packet?  Just return all the current data
        packet_data = @data.clone
        @data.replace('')
      end

      return packet_data
    end

    def reduce_to_single_packet
      return :STOP if @data.length < @min_id_size
      identify_and_finish_packet()
    end
  end
end
