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

require 'cosmos/packets/parsers/packet_parser'
require 'cosmos/tools/table_manager/table'

module Cosmos
  # Parses the TABLE keyword definition in table configuration files.
  class TableParser < PacketParser
    # @param parser [ConfigParser] Configuration parser
    # @param tables [Hash] Hash of the currently defined tables
    # @param warnings [Array<String>] Any warning strings generated while
    #   parsing this command will be appened to this array
    def self.parse_table(parser, tables, warnings)
      parser = TableParser.new(parser)
      parser.verify_parameters
      parser.create_table(tables, warnings)
    end

    # Verify the correct number of arguments to the TABLE keyword
    def verify_parameters
      @usage =
        'TABLE <TABLE NAME> <ENDIANNESS: BIG_ENDIAN/LITTLE_ENDIAN> <DISPLAY: ONE_DIMENSIONAL/TWO_DIMENSIONAL> <TWO_DIMENSIONAL TABLE ROWS> <DESCRIPTION (Optional)>'
      @parser.verify_num_parameters(3, 5, @usage)
    end

    # @param tables [Array<Table>] All tables defined in the configuration
    # @param warnings [String] List of warnings to append to
    def create_table(tables, warnings)
      params = @parser.parameters
      table_name = params[0].to_s.upcase
      endianness = params[1].to_s.upcase.to_sym
      if endianness != :BIG_ENDIAN && endianness != :LITTLE_ENDIAN
        raise @parser.error(
                "Invalid endianness #{params[1]}. Must be BIG_ENDIAN or LITTLE_ENDIAN.",
                @usage,
              )
      end
      type = params[2].to_s.upcase.to_sym
      case type
      when :ONE_DIMENSIONAL
        @parser.verify_num_parameters(3, 4, @usage)
        description = params[3].to_s
      when :TWO_DIMENSIONAL
        @parser.verify_num_parameters(4, 5, @usage)
        num_rows = params[3].to_i
        description = params[4].to_s
      else
        raise @parser.error(
                "Invalid display type #{params[2]}. Must be ONE_DIMENSIONAL or TWO_DIMENSIONAL.",
                @usage,
              )
      end
      table =
        Table.new(table_name, endianness, type, description, @parser.filename)
      table.num_rows = num_rows if type == :TWO_DIMENSIONAL
      TableParser.finish_create_table(table, tables, warnings)
    end

    protected

    def self.check_for_duplicate(tables, table)
      msg = nil
      if tables[Table::TARGET][table.table_name]
        msg = "Table #{table.table_name} redefined."
        Logger.instance.warn msg
      end
      msg
    end

    def self.finish_create_table(table, tables, warnings)
      warning = TableParser.check_for_duplicate(tables, table)
      warnings << warning if warning
      table
    end
  end
end
