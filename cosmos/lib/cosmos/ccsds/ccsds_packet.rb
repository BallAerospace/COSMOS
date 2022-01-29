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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/packets/packet'

module Cosmos
  # Packet which defines the required CCSDS items which include Version, Type,
  # Secondary Header Flag, APID, Sequence Flags, Sequence Count and Length. It
  # will optionally include a data item which will contain the rest of the
  # CCSDS packet data. This is optional to make it easier to subclass this
  # packet and add secondary header fields.
  class CcsdsPacket < Packet
    # CCSDS telemetry type
    TELEMETRY = 0
    # CCSDS telecommand type
    COMMAND = 1

    # CCSDS sequence flag indicating continuation packet
    MIDDLE = 0
    # CCSDS sequence flag indicating continuation packet
    CONTINUATION = 0
    # CCSDS sequence flag indicating the first packet
    FIRST = 1
    # CCSDS sequence flag indicating the last packet
    LAST = 2
    # CCSDS sequence flag indicating a stand alone packet
    STANDALONE = 3

    # Length Field Offset to number of bytes in entire packet
    LENGTH_FIELD_OFFSET = 7

    # Creates a CCSDS packet by setting the target and packet name and then
    # defining all the fields in a CCSDS packet with a primary header. If a
    # secondary header is desired, define a secondary header field and then
    # override the CcsdsData field to start after bit offset 48.
    #
    # @param target_name [String] The target name
    # @param packet_name [String] The packet name
    def initialize(target_name = nil, packet_name = nil, include_ccsds_data = true)
      super(target_name, packet_name, :BIG_ENDIAN)
      define_item('CcsdsVersion', 0, 3, :UINT)
      define_item('CcsdsType', 3, 1, :UINT)
      define_item('CcsdsShf', 4, 1, :UINT)
      define_item('CcsdsApid', 5, 11, :UINT)
      define_item('CcsdsSeqflags', 16, 2, :UINT)
      item = define_item('CcsdsSeqcnt', 18, 14, :UINT)
      item.overflow = :TRUNCATE
      define_item('CcsdsLength', 32, 16, :UINT)
      define_item('CcsdsData', 48, 0, :BLOCK) if include_ccsds_data
    end
  end
end # module Cosmos
