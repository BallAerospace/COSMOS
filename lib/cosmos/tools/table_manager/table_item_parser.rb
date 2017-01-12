# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/packet_config'
require 'cosmos/packets/packet_item'

module Cosmos
  class TableItemParser < PacketItemParser
    # @param parser [ConfigParser] Configuration parser
    # @param packet [Packet] The packet the item should be added to
    def self.parse(parser, table)
      parser = TableItemParser.new(parser)
      parser.verify_parameters(PacketConfig::COMMAND)
      parser.create_table_item(table)
    end

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
end # module Cosmos
