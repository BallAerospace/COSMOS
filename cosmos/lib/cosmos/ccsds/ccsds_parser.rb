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

require 'cosmos'
require 'cosmos/ccsds/ccsds_packet'

module Cosmos
  # Unsegments CCSDS packets and perform other CCSDS processing tasks.
  class CcsdsParser
    # @return [Symbol] Indicates if the parser is :READY to start a new series
    #   of packets or is :IN_PROGRESS
    attr_reader :state

    # @return [String] Binary data that has been collected so far towards the
    #   completely unsegmented packet. Note: This value is cleared once the
    #   entire packet is formed and also cleared due to errors.
    attr_reader :in_progress_data

    # @return [String] The most recent successfully unsegmented packet's data
    attr_reader :unsegmented_data

    # @return [Integer] Sequence count of the previously received packet
    attr_reader :sequence_count

    # Create a new {CcsdsPacket} and set the state to :READY
    def initialize
      @ccsds_packet = CcsdsPacket.new
      @unsegmented_data = nil
      @sequence_count = nil
      reset()
    end

    # Resets internal state to :READY and clears the in_progress_data
    def reset
      @state = :READY
      @in_progress_data = ''
    end

    # Given a segment of a larger CCSDS packet, stores the data until a complete
    # unsegmented packet can be created.  Returns the unsegmented packet data
    # once it is complete, or nil if still in progress. Raises
    # CcsdsParser::CcsdsSegmentationError if a problem is encountered while
    # unsegmenting.
    #
    # @param packet [Packet] A CCSDS packet
    # @return [String|nil] The reconstituted CCSDS packet buffer or nil if the
    #   packet has not yet been fully assembled
    def unsegment_packet(packet)
      @ccsds_packet.buffer = packet.buffer

      previous_sequence_count = @sequence_count
      @sequence_count = @ccsds_packet.read('CcsdsSeqcnt')

      # Handle each segment
      case @ccsds_packet.read('CcsdsSeqflags')
      when CcsdsPacket::CONTINUATION
        #####################################################
        # Continuation packet - only process if in progress
        #####################################################

        if @state == :IN_PROGRESS
          if @sequence_count == ((previous_sequence_count + 1) % 16384)
            @in_progress_data << @ccsds_packet.read('CcsdsData')
            return nil
          else
            reset()
            raise CcsdsSegmentationError, "Missing packet(s) before continuation packet detected. Current Sequence Count #{@sequence_count}, Previous Sequence Count #{previous_sequence_count}"
          end
        else
          reset()
          raise CcsdsSegmentationError, "Unexpected continuation packet"
        end

      when CcsdsPacket::FIRST
        #######################################################
        # First packet - always process
        #######################################################

        if @state == :IN_PROGRESS
          reset()
          @state = :IN_PROGRESS
          @in_progress_data << @ccsds_packet.buffer
          raise CcsdsSegmentationError, "Unexpected first packet"
        else
          @state = :IN_PROGRESS
          @in_progress_data << @ccsds_packet.buffer
          return nil
        end

      when CcsdsPacket::LAST
        ######################################################################
        # Last packet - only process if in progress
        ######################################################################

        if @state == :IN_PROGRESS
          if @sequence_count == ((previous_sequence_count + 1) % 16384)
            @in_progress_data << @ccsds_packet.read('CcsdsData')
            @unsegmented_data = @in_progress_data
            reset()
            return @unsegmented_data
          else
            reset()
            raise CcsdsSegmentationError, "Missing packet(s) before last packet detected. Current Sequence Count #{@sequence_count}, Previous Sequence Count #{previous_sequence_count}"
          end
        else
          reset()
          raise CcsdsSegmentationError, "Unexpected last packet"
        end

      when CcsdsPacket::STANDALONE
        ############################################################
        # Standalone packet - save and return its data
        ############################################################

        # Update most recent unsegmented data
        @unsegmented_data = @ccsds_packet.buffer

        if @state == :IN_PROGRESS
          reset()
          raise CcsdsSegmentationError, "Unexpected standalone packet"
        else
          reset()
          return @unsegmented_data
        end

      end # case raw_sequence_flags
    end

    # Class to indicate errors that occur during the unsegmenting process
    class CcsdsSegmentationError < StandardError; end
  end # end class CcsdsParser
end # module Cosmos
