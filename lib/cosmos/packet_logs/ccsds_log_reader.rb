# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packet_logs/packet_log_reader'
require 'cosmos/ccsds/ccsds_packet'

module Cosmos

  # Reads a CCSDS packet log of either commands or telemetry.
  class CcsdsLogReader < PacketLogReader

    # Length of the header on a CCSDS source packet
    CCSDS_HEADER_LENGTH = 6

    # Create a new log file reader
    def initialize
      super()
      @ccsds_header = CcsdsPacket.new(nil, nil, false)
    end

    # Read a packet from the log file
    #
    # @param identify_and_define (see #each)
    # @return [Packet]
    def read(identify_and_define = true)
      # Read the CCSDS packet header
      header = @file.read(CCSDS_HEADER_LENGTH)
      return nil unless header and header.length == CCSDS_HEADER_LENGTH
      @ccsds_header.buffer = header

      # Extract the length field
      length = @ccsds_header.read('CcsdsLength') + 1

      # Read the remainder of the packet data
      data = @file.read(length)
      return nil unless data and data.length == length

      # Combine into the full packet data
      packet_data = header << data

      # Determine packet time and set it as received time
      received_time = determine_received_time(packet_data)

      # Build the actual Packet object
      if identify_and_define
        packet = identify_and_define_packet_data(nil, nil, received_time, packet_data)
      else
        # Build Packet
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, packet_data)
        packet.set_received_time_fast(received_time)
      end

      # Return the packet
      packet
    rescue => err
      close()
      raise err
    end

    protected

    # TODO : Add code here or in subclass to derive received time from the packet timestamp
    # CCSDS timestamp formats and even the presence of a timestamp vary
    def determine_received_time(packet_data)
      nil
    end

    def read_file_header
      # Read the first CCSDS packet header
      header = @file.read(CCSDS_HEADER_LENGTH)

      if header and header.length == CCSDS_HEADER_LENGTH
        @ccsds_header.buffer = header
        packet_type = @ccsds_header.read('CcsdsType')
        if packet_type == CcsdsPacket::TELEMETRY
          @log_type = :TLM
        else
          @log_type = :CMD
        end
        @configuration_name = nil
        @hostname = nil
        @file_header_length = 0
        @file.seek(0, IO::SEEK_SET)
        System.load_configuration(nil)
      else
        raise "Failed to read at least #{CCSDS_HEADER_LENGTH} bytes from packet log"
      end
    end

    def seek_to_time(time)
      # Not supported
    end

  end # class CcsdsLogReader

end # module Cosmos
