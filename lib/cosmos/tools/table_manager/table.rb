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
    TARGET = 'TABLE'
    attr_reader :type, :filename
    attr_accessor :num_rows, :num_columns

    def table_name
      packet_name
    end

    # Constructor for a TableDefinition
    def initialize(name, endianness, type, description, filename)
      super(TARGET, name, endianness, description, '', TableItem)
      if type != :ONE_DIMENSIONAL && type != :TWO_DIMENSIONAL
        raise ArgumentError, "Invalid type '#{type}' for table '#{name}'. Must be ONE_DIMENSIONAL or TWO_DIMENSIONAL"
      end
      @type = type
      @filename = filename
      @num_columns = 0
      @num_rows = 0
      @num_columns = 1 if @type == :ONE_DIMENSIONAL
    end

  end
end

