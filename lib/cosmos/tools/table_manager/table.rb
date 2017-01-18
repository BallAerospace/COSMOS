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
    # Define the target for tables as 'TABLE' since there is no target
    TARGET = 'TABLE'
    # @return [Symbol] Either :ONE_DIMENSIONAL or :TWO_DIMENSIONAL
    attr_reader :type
    # @return [String] File which contains the table definition
    attr_reader :filename
    # @return [Integer] Number of columns in the table
    attr_accessor :num_columns

    alias table_name packet_name

    # Constructor for a TableDefinition
    def initialize(name, endianness, type, description, filename)
      super(TARGET, name, endianness, description, '', TableItem)
      if type != :ONE_DIMENSIONAL && type != :TWO_DIMENSIONAL
        raise ArgumentError, "Invalid type '#{type}' for table '#{name}'. Must be ONE_DIMENSIONAL or TWO_DIMENSIONAL"
      end
      @type = type
      @filename = filename
      @num_rows = 0
      @num_columns = (@type == :ONE_DIMENSIONAL) ? 1 : 0
    end

    # @param num_rows [Integer] Set the number of rows in a TWO_DIMENSIONAL table
    def num_rows=(num_rows)
      case @type
      when :ONE_DIMENSIONAL
        raise "Rows are fixed in a ONE_DIMENSIONAL table"
      when :TWO_DIMENSIONAL
        @num_rows = num_rows
      end
    end

    # @return [Integer] Number of rows in the table
    def num_rows
      case @type
      when :ONE_DIMENSIONAL
        @sorted_items.count {|item| !item.hidden }
      when :TWO_DIMENSIONAL
        @num_rows
      end
    end
  end
end
