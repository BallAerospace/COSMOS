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

require 'cosmos/packets/packet_config'
require 'cosmos/packets/parsers/packet_item_parser'
require 'cosmos/tools/table_manager/table_item'

module Cosmos
  # Extends the PacketItemParser to create TableItems for TableManager
  class TableItemParser < PacketItemParser
    # @param parser [ConfigParser] Configuration parser
    # @param table [Table] Table all parsed items should be added to
    # # @param warnings [Array<String>] Array of warning strings from PacketConfig
    def self.parse(parser, table, warnings)
      parser = TableItemParser.new(parser, warnings)
      parser.verify_parameters(PacketConfig::COMMAND)
      parser.create_table_item(table)
    end

    # @param table [Table] Table created items are added to
    def create_table_item(table)
      name = @parser.parameters[0]
      if table.type == :TWO_DIMENSIONAL
        name = "#{name}0"
        table.num_columns += 1
      end
      item = TableItem.new(name, get_bit_offset(), get_bit_size(), get_data_type(),
                           get_endianness(table), get_array_size(), :ERROR) # overflow
      item.range = get_range()
      item.default = get_default()
      item.description = get_description()
      if append?
        item = table.append(item)
      else
        item = table.define(item)
      end
      item
    rescue => err
      raise @parser.error(err, @usage)
    end
  end
end
