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
require 'cosmos/tools/table_manager/table_item'

module Cosmos
  # Table extends Packet by adding more attributes relative to
  # displaying binary data in a gui.
  class Table < Packet
    # Define the target for tables as 'TABLE' since there is no target
    TARGET = 'TABLE'

    # @return [Symbol] Either :KEY_VALUE or :ROW_COLUMN
    attr_reader :type

    # @return [String] File which contains the table definition
    attr_reader :filename

    # @return [Integer] Number of columns in the table
    attr_accessor :num_columns

    alias table_name packet_name

    # Constructor for a TableDefinition
    def initialize(name, endianness, type, description, filename)
      super(TARGET, name, endianness, description, '', TableItem)
      # ONE_DIMENSIONAL and TWO_DIMENSIONAL are deprecated so translate
      type = :KEY_VALUE if type == :ONE_DIMENSIONAL
      type = :ROW_COLUMN if type == :TWO_DIMENSIONAL
      if type != :KEY_VALUE && type != :ROW_COLUMN
        raise ArgumentError,
              "Invalid type '#{type}' for table '#{name}'. Must be KEY_VALUE or ROW_COLUMN"
      end
      @type = type
      @filename = filename
      @num_rows = 0
      @num_columns = (@type == :KEY_VALUE) ? 1 : 0
    end

    # @param num_rows [Integer] Set the number of rows in a ROW_COLUMN table
    def num_rows=(num_rows)
      case @type
      when :KEY_VALUE
        raise 'Rows are fixed in a KEY_VALUE table'
      when :ROW_COLUMN
        @num_rows = num_rows
      end
    end

    # @return [Integer] Number of rows in the table
    def num_rows
      case @type
      when :KEY_VALUE
        @sorted_items.count { |item| !item.hidden }
      when :ROW_COLUMN
        @num_rows
      end
    end
  end
end
