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

module Cosmos
  module PacketLogConstants
    # Constants to detect old file formats
    COSMOS2_FILE_HEADER = 'COSMOS2_'.freeze
    COSMOS4_FILE_HEADER = 'COSMOS4_'.freeze

    # COSMOS 5 Constants
    COSMOS5_FILE_HEADER = 'COSMOS5_'.freeze
    COSMOS5_INDEX_HEADER = 'COSIDX5_'.freeze
    COSMOS5_HEADER_LENGTH = COSMOS5_FILE_HEADER.length
    # Flags which are bit masked into file entries
    COSMOS5_ENTRY_TYPE_MASK = 0xF000
    COSMOS5_TARGET_DECLARATION_ENTRY_TYPE_MASK = 0x1000
    COSMOS5_PACKET_DECLARATION_ENTRY_TYPE_MASK = 0x2000
    COSMOS5_RAW_PACKET_ENTRY_TYPE_MASK = 0x3000
    COSMOS5_JSON_PACKET_ENTRY_TYPE_MASK = 0x4000
    COSMOS5_OFFSET_MARKER_ENTRY_TYPE_MASK = 0x5000
    COSMOS5_ID_FLAG_MASK = 0x0200
    COSMOS5_STORED_FLAG_MASK = 0x0400
    COSMOS5_CMD_FLAG_MASK = 0x0800

    COSMOS5_ID_FIXED_SIZE = 32
    COSMOS5_MAX_PACKET_INDEX = 65535
    COSMOS5_MAX_TARGET_INDEX = 65535

    COSMOS5_PRIMARY_FIXED_SIZE = 2
    COSMOS5_TARGET_DECLARATION_SECONDARY_FIXED_SIZE = 0
    COSMOS5_TARGET_DECLARATION_PACK_DIRECTIVE = 'Nn'.freeze
    COSMOS5_TARGET_DECLARATION_PACK_ITEMS = 2 # Useful for testing
    
    COSMOS5_PACKET_DECLARATION_SECONDARY_FIXED_SIZE = 2
    COSMOS5_PACKET_DECLARATION_PACK_DIRECTIVE = 'Nnn'.freeze
    COSMOS5_PACKET_DECLARATION_PACK_ITEMS = 3 # Useful for testing
    
    COSMOS5_OFFSET_MARKER_SECONDARY_FIXED_SIZE = 0
    COSMOS5_OFFSET_MARKER_PACK_DIRECTIVE = 'Nn'.freeze
    COSMOS5_OFFSET_MARKER_PACK_ITEMS = 2 # Useful for testing
    
    COSMOS5_PACKET_SECONDARY_FIXED_SIZE = 10
    COSMOS5_PACKET_PACK_DIRECTIVE = 'NnnQ>'.freeze
    COSMOS5_PACKET_PACK_ITEMS = 4 # Useful for testing
  end
end
