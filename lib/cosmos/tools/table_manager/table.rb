# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/table_manager/table_item'

module Cosmos

  # Table extends Packet by adding more attributes relative to
  # displaying binary data in a gui.
  class Table < Packet
    attr_accessor :num_rows
    attr_accessor :num_columns
    attr_reader :name
    attr_reader :type
    attr_reader :table_id
    attr_reader :filename

    # Constructor for a TableDefinition
    def initialize(name, description, type, endianness, table_id, filename)
      super('TABLE', name, endianness, description, '', TableItem)
      @name = name
      @type = type
      @table_id = table_id
      @filename = filename
      @num_columns = 0
      @num_rows = 0
      @num_columns = 1 if @type == :ONE_DIMENSIONAL
    end

    # Calls define_item in Packet but also incrememts @num_columns
    # if this table is a REPEATING table.
    def create_param(name, bit_offset, bit_size, type, description, range, default, display_type, editable)
      @num_columns += 1 if @type == :TWO_DIMENSIONAL
      item = define_item(name, bit_offset, bit_size, type)
      item.description = description
      item.range = range
      item.default = default
      item.display_type = display_type
      item.editable = editable
      item
    end

    # Calls define_packet_item in GenericPacket to duplicate the passed in packet
    # item. name_extension is concatenated with the orignal item name to make it
    # unique.
    def duplicate_item(item, name_extension, bit_offset)
      new_item = define_item("#{item.name[0...-1]}#{name_extension}",
                             bit_offset, item.bit_size, item.data_type, item.array_size,
                             item.endianness, item.overflow,
                             item.format_string, item.read_conversion,
                             item.write_conversion, item.id_value)
      new_item.description = item.description
      new_item.range = item.range
      new_item.display_type = item.display_type
      new_item.editable = item.editable
      new_item.states = item.states
      new_item.constraint = item.constraint
      new_item
    end
  end # class Table

end # module Cosmos
