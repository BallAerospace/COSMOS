# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/config/config_parser'
require 'cosmos/packets/packet_config'
require 'cosmos/tools/table_manager/table'
require 'cosmos/tools/table_manager/table_parser'
require 'cosmos/tools/table_manager/table_item_parser'

module Cosmos
  # Processes the Table Manager configuration files which define tables. Since
  # this class inherits from {PacketConfig} it only needs to implement Table
  # Manager specific keywords. All tables are accessed through the table
  # and tables methods.
  class TableConfig < PacketConfig
    # @return [String] Table configuration filename
    attr_reader :filename

    # Create the table configuration
    def initialize
      super
      # Override commands with the Table::TARGET name to store tables
      @commands[Table::TARGET] = {}
    end

    # @return [Array<Table>] All tables defined in the configuration file
    def tables
      @commands[Table::TARGET]
    end

    # @return [Array<String>] All the table names
    def table_names
      tables.keys
    end

    # @param table_name [String] Table name to return
    # @return [Table]
    def table(table_name)
      tables[table_name.upcase]
    end

    # Processes a COSMOS table configuration file and uses the keywords to build up
    # knowledge of the tables.
    #
    # @param filename [String] The name of the configuration file
    def process_file(filename)
      # Partial files are included into another file and thus aren't directly processed
      return if File.basename(filename)[0] == '_' # Partials start with underscore
      @filename = filename
      @converted_type = nil
      @converted_bit_size = nil
      @proc_text = ''
      @building_generic_conversion = false

      parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#table-manager-configuration-cosmos--39")
      parser.parse_file(filename) do |keyword, params|
        if @building_generic_conversion
          case keyword
          # Complete a generic conversion
          when 'GENERIC_READ_CONVERSION_END', 'GENERIC_WRITE_CONVERSION_END'
            parser.verify_num_parameters(0, 0, keyword)
            @current_item.read_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "READ"
            @current_item.write_conversion =
              GenericConversion.new(@proc_text,
                                    @converted_type,
                                    @converted_bit_size) if keyword.include? "WRITE"
            @building_generic_conversion = false
          # Add the current config.line to the conversion being built
          else
            @proc_text << parser.line << "\n"
          end # case keyword

        else # not building generic conversion
          case keyword
          when 'TABLEFILE'
            usage = "#{keyword} <File name>"
            parser.verify_num_parameters(1, 1, usage)
            table_filename = File.join(File.dirname(filename), params[0])
            raise parser.error("Table file #{table_filename} not found", usage) unless File.exist?(table_filename)
            process_file(table_filename)

          when 'TABLE'
            finish_packet()
            @current_packet = TableParser.parse_table(parser, @commands, @warnings)
            @current_cmd_or_tlm = COMMAND

          # Select an existing table for editing
          when 'SELECT_TABLE'
            usage = "#{keyword} <TABLE NAME>"
            finish_packet()
            parser.verify_num_parameters(1, 1, usage)
            table_name = params[0].upcase
            @current_packet = table(table_name)
            raise parser.error("Table #{table_name} not found", usage) unless @current_packet

          #######################################################################
          # All the following keywords must have a current packet defined
          #######################################################################
          when 'SELECT_PARAMETER', 'PARAMETER', 'ID_PARAMETER', 'ARRAY_PARAMETER',
            'APPEND_PARAMETER', 'APPEND_ID_PARAMETER', 'APPEND_ARRAY_PARAMETER',
            'ALLOW_SHORT', 'HAZARDOUS', 'PROCESSOR', 'META', 'DISABLE_MESSAGES', 'DISABLED'
            raise parser.error("No current packet for #{keyword}") unless @current_packet
            process_current_packet(parser, keyword, params)

          #######################################################################
          # All the following keywords must have a current item defined
          #######################################################################
          when 'STATE', 'READ_CONVERSION', 'WRITE_CONVERSION', 'POLY_READ_CONVERSION',
            'POLY_WRITE_CONVERSION', 'SEG_POLY_READ_CONVERSION', 'SEG_POLY_WRITE_CONVERSION',
            'GENERIC_READ_CONVERSION_START', 'GENERIC_WRITE_CONVERSION_START', 'REQUIRED',
            'LIMITS', 'LIMITS_RESPONSE', 'UNITS', 'FORMAT_STRING', 'DESCRIPTION', 'HIDDEN',
            'MINIMUM_VALUE', 'MAXIMUM_VALUE', 'DEFAULT_VALUE', 'OVERFLOW', 'UNEDITABLE'
            raise parser.error("No current item for #{keyword}") unless @current_item
            process_current_item(parser, keyword, params)

          else
            # blank config.lines will have a nil keyword and should not raise an exception
            raise parser.error("Unknown keyword '#{keyword}'") if keyword
          end # case keyword
        end
      end

      # Complete the last defined packet
      finish_packet()
    end

    # (see PacketConfig#process_current_packet)
    def process_current_packet(parser, keyword, params)
      super(parser, keyword, params)
    rescue => err
      if err.message.include?("not found")
        raise parser.error("#{params[0]} not found in table #{@current_packet.table_name}", "SELECT_PARAMETER <PARAMETER NAME>")
      else
        raise err
      end
    end

    # Overridden method to handle the unique table item parameters: UNEDITABLE
    # and HIDDEN.
    # (see PacketConfig#process_current_item)
    def process_current_item(parser, keyword, params)
      super(parser, keyword, params)
      case keyword
      when 'UNEDITABLE'
        usage = "#{keyword}"
        parser.verify_num_parameters(0, 0, usage)
        @current_item.editable = false
      when 'HIDDEN'
        usage = "#{keyword}"
        parser.verify_num_parameters(0, 0, usage)
        @current_item.hidden = true
      end
    end

    # (see PacketConfig#start_item)
    def start_item(parser)
      finish_item()
      @current_item = TableItemParser.parse(parser, @current_packet, @warnings)
    end

    # If the table is TWO_DIMENSIONAL all currently defined items are
    # duplicated until the specified number of rows are created.
    def finish_packet
      if @current_packet
        warnings = @current_packet.check_bit_offsets
        raise "Overlapping items not allowed in tables.\n#{warnings}" if warnings.length > 0
        if @current_packet.type == :TWO_DIMENSIONAL
          items = @current_packet.sorted_items.clone
          (@current_packet.num_rows - 1).times do |row|
            items.each do |item|
              new_item = item.clone
              new_item.name = "#{new_item.name[0...-1]}#{row + 1}"
              @current_packet.append(new_item)
            end
          end
        end
      end
      super()
    end
  end
end
