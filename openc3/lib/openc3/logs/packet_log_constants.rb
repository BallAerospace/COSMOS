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

module OpenC3
  module PacketLogConstants
    # Constants to detect old file formats
    COSMOS2_FILE_HEADER = 'COSMOS2_'.freeze
    COSMOS4_FILE_HEADER = 'COSMOS4_'.freeze

    # OPENC3 5 Constants
    OPENC3_FILE_HEADER = 'OPENC3_5'.freeze
    OPENC3_INDEX_HEADER = 'OC3IDX_5'.freeze
    OPENC3_HEADER_LENGTH = OPENC3_FILE_HEADER.length
    # Flags which are bit masked into file entries
    OPENC3_ENTRY_TYPE_MASK = 0xF000
    OPENC3_TARGET_DECLARATION_ENTRY_TYPE_MASK = 0x1000
    OPENC3_PACKET_DECLARATION_ENTRY_TYPE_MASK = 0x2000
    OPENC3_RAW_PACKET_ENTRY_TYPE_MASK = 0x3000
    OPENC3_JSON_PACKET_ENTRY_TYPE_MASK = 0x4000
    OPENC3_OFFSET_MARKER_ENTRY_TYPE_MASK = 0x5000
    OPENC3_ID_FLAG_MASK = 0x0200
    OPENC3_STORED_FLAG_MASK = 0x0400
    OPENC3_CMD_FLAG_MASK = 0x0800

    OPENC3_ID_FIXED_SIZE = 32
    OPENC3_MAX_PACKET_INDEX = 65535
    OPENC3_MAX_TARGET_INDEX = 65535

    OPENC3_PRIMARY_FIXED_SIZE = 2
    OPENC3_TARGET_DECLARATION_SECONDARY_FIXED_SIZE = 0
    OPENC3_TARGET_DECLARATION_PACK_DIRECTIVE = 'Nn'.freeze
    OPENC3_TARGET_DECLARATION_PACK_ITEMS = 2 # Useful for testing

    OPENC3_PACKET_DECLARATION_SECONDARY_FIXED_SIZE = 2
    OPENC3_PACKET_DECLARATION_PACK_DIRECTIVE = 'Nnn'.freeze
    OPENC3_PACKET_DECLARATION_PACK_ITEMS = 3 # Useful for testing

    OPENC3_OFFSET_MARKER_SECONDARY_FIXED_SIZE = 0
    OPENC3_OFFSET_MARKER_PACK_DIRECTIVE = 'Nn'.freeze
    OPENC3_OFFSET_MARKER_PACK_ITEMS = 2 # Useful for testing

    OPENC3_PACKET_SECONDARY_FIXED_SIZE = 10
    OPENC3_PACKET_PACK_DIRECTIVE = 'NnnQ>'.freeze
    OPENC3_PACKET_PACK_ITEMS = 4 # Useful for testing
  end
end
