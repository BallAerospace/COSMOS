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

require 'openc3'
require 'openc3/tools/table_manager/table_config'

module OpenC3
  # Provides the low level Table Manager methods which do not require a GUI.
  class TableManagerCore
    # Generic error raised when a more specific error doesn't work
    class CoreError < StandardError
    end

    # Raised when opening a file that is either larger or smaller than its definition
    class MismatchError < CoreError
    end

    def self.binary(binary, definition_filename, table_name)
      config = TableConfig.process_file(definition_filename)
      load_binary(config, binary)
      return config.table(table_name).buffer
    end

    def self.definition(definition_filename, table_name)
      config = TableConfig.process_file(definition_filename)
      return config.definition(table_name) # This returns an array: [filename, contents]
    end

    def self.report(binary, definition_filename, requested_table_name = nil)
      report = StringIO.new
      config = TableConfig.process_file(definition_filename)
      begin
        load_binary(config, binary)
      rescue CoreError => err
        report.puts "Error: #{err.message}\n"
      end

      config.tables.each do |table_name, table|
        next if requested_table_name && table_name != requested_table_name
        items = table.sorted_items
        report.puts(table.table_name)

        # Write the column headers
        if table.type == :ROW_COLUMN
          columns = ['Item']

          # Remove the '0' from the 'itemname0'
          table.num_columns.times.each do |x|
            columns << items[x].name[0...-1]
          end
          report.puts columns.join(', ')
        else
          report.puts 'Label, Value'
        end

        # Write the table item values
        (0...table.num_rows).each do |r|
          if table.type == :ROW_COLUMN
            rowtext = "#{r + 1}"
          else
            rowtext = items[r].name
          end

          report.write "#{rowtext}, "
          (0...table.num_columns).each do |c|
            if table.type == :ROW_COLUMN
              table_item = items[c + r * table.num_columns]
            else
              table_item = items[r]
            end
            value = table.read(table_item.name, :FORMATTED)
            if value.is_printable?
              report.write "#{value}, "
            else
              report.write "#{value.simple_formatted}, "
            end
          end
          report.write("\n") # newline after each row
        end
        report.write("\n") # newline after each table
      end
      report.string
    end

    def self.generate(definition_filename)
      config = TableConfig.process_file(definition_filename)
      binary = ''
      config.tables.each do |table_name, table|
        table.restore_defaults
        binary += table.buffer
      end
      binary
    end

    def self.save(definition_filename, tables)
      config = TableConfig.process_file(definition_filename)
      tables.each do |table|
        table_def = config.tables[table['name']]
        table['rows'].each do |row|
          row.each do |item|
            # TODO: I don't know how the frontend could edit an item like this:
            # item:{"name"=>"BINARY", "value"=>{"json_class"=>"String", "raw"=>[222, 173, 190, 239]} }
            next if item['value'].is_a? Hash
            table_def.write(item['name'], item['value'])
          end
        end
      end
      binary = ''
      config.tables.each { |table_name, table| binary += table.buffer }
      binary
    end

    def self.build_json(binary, definition_filename)
      config = TableConfig.process_file(definition_filename)
      tables = []
      json = { tables: tables }
      begin
        load_binary(config, binary)
      rescue CoreError => err
        json['errors'] = err.message
      end
      config.tables.each do |table_name, table|
        tables << {
          name: table_name,
          numRows: table.num_rows,
          numColumns: table.num_columns,
          headers: [],
          rows: [],
        }
        col = 0
        row = 0
        num_cols = table.num_columns
        table.sorted_items.each_with_index do |item, index|
          next if item.hidden
          if table.num_columns == 1
            if row == 0
              tables[-1][:headers] = [ "INDEX", "NAME", "VALUE" ]
            end
            tables[-1][:rows] << [
              {
                index: row + 1,
                name: item.name,
                value: table.read(item.name, :FORMATTED),
                states: item.states,
                editable: item.editable,
              },
            ]
          else
            if row == 0 && col == 0
              tables[-1][:headers] << "INDEX"
            end
            if row == 0
              tables[-1][:headers] << item.name[0..-2]
            end
            if col == 0
              # Each row is an array of items
              tables[-1][:rows][row] = []
            end
            tables[-1][:rows][row] << {
              index: row + 1,
              name: item.name,
              value: table.read(item.name, :FORMATTED),
              states: item.states,
              editable: item.editable,
            }
          end
          col += 1
          if col == table.num_columns
            col = 0
            row += 1
          end
        end
      end
      json.as_json(:allow_nan => true).to_json(:allow_nan => true)
    end

    def self.load_binary(config, data)
      binary_data_index = 0
      total_table_length = 0
      config.tables.each do |table_name, table|
        total_table_length += table.length
      end
      config.tables.each do |table_name, table|
        if binary_data_index + table.length > data.length
          table.buffer = data[binary_data_index..-1]
          raise MismatchError,
            "Binary size of #{data.length} not large enough to fully represent table definition of length #{total_table_length}. "+
            "The remaining table definition (starting with byte #{data.length - binary_data_index} in #{table.table_name}) will be filled with 0."
        end
        table.buffer = data[binary_data_index...binary_data_index + table.length]
        binary_data_index += table.length
      end
      if binary_data_index < data.length
        raise MismatchError,
          "Binary size of #{data.length} larger than table definition of length #{total_table_length}. "+
          "Discarding the remaing #{data.length - binary_data_index} bytes."
      end
    end

    # TODO: Potentially useful methods?
    # # @return [String] Success string if parameters all check. Raises
    # #   a CoreError if errors are found.
    # def file_check
    #   raise NoConfigError unless @config
    #   result = ''
    #   @config.table_names.each do |name|
    #     table_result = table_check(name)
    #     unless table_result.empty?
    #       result << "Errors in #{name}:\n" + table_result
    #     end
    #   end
    #   raise CoreError, result unless result.empty?
    #   'All parameters are within their constraints.'
    # end

    # # Create a hex formatted string of all the file data
    # def file_hex
    #   raise NoConfigError unless @config
    #   data = ''
    #   @config.tables.values.each { |table| data << table.buffer }
    #   "#{data.formatted}\n\nTotal Bytes Read: #{data.length}"
    # end

    # # @param table_name [String] Name of the table to check for out of range values
    # def table_check(table_name)
    #   raise NoConfigError unless @config
    #   table = @config.table(table_name)
    #   raise NoTableError unless table

    #   result = ''
    #   table_items = table.sorted_items

    #   # Check the ranges and constraints for each item in the table
    #   # We go through it this way (by row and columns) so we can grab the actual
    #   # user input when we display any errors found
    #   (0...table.num_rows).each do |r|
    #     (0...table.num_columns).each do |c|
    #       # get the table item definition so we know how to save it
    #       table_item = table_items[r * table.num_columns + c]

    #       value = table.read(table_item.name)
    #       unless table_item.range.nil?
    #         # If the item has states which include the value, then convert
    #         # the state back to the numeric value for range checking
    #         if table_item.states && table_item.states.include?(value)
    #           value = table_item.states[value]
    #         end

    #         # check to see if the value lies within its valid range
    #         unless table_item.range.include?(value)
    #           if table_item.format_string
    #             value = table.read(table_item.name, :FORMATTED)
    #             range_first =
    #               sprintf(table_item.format_string, table_item.range.first)
    #             range_last =
    #               sprintf(table_item.format_string, table_item.range.last)
    #           else
    #             range_first = table_item.range.first
    #             range_last = table_item.range.last
    #           end
    #           result <<
    #             "  #{table_item.name}: #{value} outside valid range of #{range_first}..#{range_last}\n"
    #         end
    #       end
    #     end # end each column
    #   end # end each row
    #   result
    # end

    # # @param table_name [String] Create a hex formatted string of the given table data
    # def table_hex(table_name)
    #   raise NoConfigError unless @config
    #   table = @config.table(table_name)
    #   raise NoTableError unless table
    #   "#{table.buffer.formatted}\n\nTotal Bytes Read: #{table.buffer.length}"
    # end

    # # Commit a table from the current configuration into a new binary
    # #
    # # @param table_name [String] Table name to commit to an existing binary
    # # @param bin_file [String] Binary file to open
    # # @param def_file [String] Definition file to use when opening
    # def table_commit(table_name, bin_file, def_file)
    #   raise NoConfigError unless @config
    #   save_table = @config.table(table_name)
    #   raise NoTableError unless save_table

    #   result = table_check(table_name)
    #   unless result.empty?
    #     raise CoreError, "Errors in #{table_name}:\n#{result}"
    #   end

    #   config = TableConfig.new
    #   begin
    #     config.process_file(def_file)
    #   rescue => err
    #     raise CoreError,
    #           "The table definition file:#{def_file} has the following errors:\n#{err}"
    #   end

    #   if !config.table_names.include?(table_name.upcase)
    #     raise NoTableError,
    #           "#{table_name} not found in #{def_file} table definition file."
    #   end

    #   saved_config = @config
    #   @config = config
    #   open_and_load_binary_file(bin_file)

    #   # Store the saved table data in the new table definition
    #   table = config.table(save_table.table_name)
    #   table.buffer = save_table.buffer[0...table.length]
    #   file_save(bin_file)
    #   @config = saved_config
    # end
  end
end
