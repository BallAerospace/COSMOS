# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/table_manager/table_config'

module Cosmos

  class TableManagerCore
    attr_reader :config, :definition_filename#, :binary_filename

    def initialize
      reset()
    end

    def reset
    #  @binary_filename = nil
      @definition_filename = nil
      @config = nil
    end

    def process_definition(filename)
      @definition_filename = filename
      @config = TableConfig.new()
      @config.process_file(filename)
    end

    def file_new(definition_filename, output_dir)
      progress = 0.0
      process_definition(definition_filename)
      yield 0.3 if block_given?

      @config.table_names.each {|table_name| set_binary_data_to_default(table_name) }
      yield 0.7 if block_given?

      file_save(File.join(output_dir, def_to_bin_filename(definition_filename)))
    end

    def file_check
      raise "Please open a table first." unless @config

      result = ""
      @config.table_names.each do |name|
        table_result = table_check(name)
        unless table_result.empty?
          result << "Error(s) in #{name}:\n" + table_result
        end
      end
      raise result unless result.empty?
    end

    def file_save(filename)
      raise "Please open a table first." unless @config
      file_check()
      File.open(filename, "wb") do |file|
        @config.tables.each do |table_name, table|
          file.write(table.buffer)
        end
      end
      file_report(filename)
    end

    # Generate the RPT file for the currently opened file
    def file_report(binary_filename)
      raise "Please open a table first." unless @config
      file_check()

      filename = File.basename(binary_filename, ".dat")
      File.open(File.join(File.dirname(binary_filename), "#{filename}.txt"), 'w+') do |file|
        file.write("File Definition: #{@definition_file}\n")
        file.write("File Binary: #{binary_filename}\n\n")
        @config.tables.values.each do |table|
          items = table.sorted_items
          file.puts(table.name)

          column_lengths = []

          if table.type == :TWO_DIMENSIONAL
            column_lengths[0] = "Item".length
          else
            column_lengths[0] = "Label".length
          end

          # Determine the maximum length of all the row header text in the table
          # Basically we're treating the row headers as column 0 when we output
          # the data which is why we set column_lengths[0] with the row text length
          (0...table.num_rows).each do |r|
            if table.type == :TWO_DIMENSIONAL
              rowtext = "#{r+1}"
            else
              rowtext = items[r].name
            end

            if rowtext.length > column_lengths[0]
              column_lengths[0] = rowtext.length
            end
          end

          # Collect the column header text length in the table
          # Since the row headers were column 0 that is why we increment the column
          # header by 1 (column_lengths[c+1]) before setting the column text length
          (0...table.num_columns).each do |c|
            if table.type == :TWO_DIMENSIONAL
              columntext = items[c].name[0...-1]
            else
              columntext = "Value"
            end
            column_lengths[c+1] = columntext.length
          end

          # Determine the maximum length item in each column of the table
          # We can simply go throught the gui table by row and column looking for
          # the widest value
          (0...table.num_rows).each do |r|
            (0...table.num_columns).each do |c|
              if table.type == :TWO_DIMENSIONAL
                table_item = items[c + r * table.num_columns]
              else
                table_item = items[r]
              end
              value = item_to_report_string(table, table_item)

              if value.length > column_lengths[c+1]
                column_lengths[c+1] = value.length
              end

            end
          end

          # Write out the first column header depending on the table type
          if table.type == :TWO_DIMENSIONAL
            file.printf("%-#{column_lengths[0]}s ", "Item")
          else
            file.printf("%-#{column_lengths[0]}s ", "Label")
          end

          # Write out all the column header text
          (0...table.num_columns).each do |c|
            if table.type == :TWO_DIMENSIONAL
              columntext = items[c].name[0...-1]
            else
              columntext = "Value"
            end

            file.printf("%-#{column_lengths[c+1]}s ", columntext)
          end
          file.write("\n")

          # Write out the table items
          (0...table.num_rows).each do |r|
            if table.type == :TWO_DIMENSIONAL
              rowtext = "#{r+1}"
            else
              rowtext = items[r].name
            end

            file.printf("%-#{column_lengths[0]}s ", rowtext)
            (0...table.num_columns).each do |c|
              if table.type == :TWO_DIMENSIONAL
                table_item = items[c + r * table.num_columns]
              else
                table_item = items[r]
              end

              value = item_to_report_string(table, table_item)

              file.printf("%-#{column_lengths[c+1]}s ", value)

            end
            file.write("\n") # newline after each row
          end
          file.write("\n") # newline after each table
        end
      end
    end

    def file_open(definition_filename, binary_filename)
      process_definition(definition_filename)
      open_and_load_binary_file(binary_filename)
    end

    def file_hex
      raise "Please open a table first." unless @config
      data = ""
      @config.tables.values.each {|table| data << table.buffer }
      "#{data.formatted}\n\nTotal Bytes Read: #{data.length}"
    end

    def table_check(table_name)
      raise "Please open a table first." unless @config

      table = @config.table(table_name)
      raise "Please open a table first." unless table

      result = ""
      table_items = table.sorted_items

      # Check the ranges and constraints for each item in the table
      # We go through it this way (by row and columns) so we can grab the actual
      # user input when we display any errors found
      (0...table.num_rows).each do |r|
        (0...table.num_columns).each do |c|
          # get the table item definition so we know how to save it
          table_item = table_items[r * table.num_columns + c]

          # if a constraint was defined call it here
          # this should set the underlying constraints
          if (table_item.constraint != nil)
            table_item.constraint.call(table_item, table, table.buffer)
          end

          x = table.read(table_item.name, :RAW)
          if table_item.data_type == :STRING
            if x.length > table_item.bit_size / 8
              result << "  #{table_item.name}: #{x} must be less than #{table_item.bit_size / 8} characters\n"
            end
          end

          unless table_item.range.nil?
            # check to see if the value lies within its valid range
            if not table_item.range.include?(x)
              # if the value is displayed as hex, display the range as hex
              if table_item.display_type == :HEX
                range_first = "0x%X" % table_item.range.first
                range_last = "0x%X" % table_item.range.last
                x = "0x%X" % x
              else
                range_first = table_item.range.first
                range_last = table_item.range.last
                x = table.read(table_item.name)
              end
              result << "  #{table_item.name}: #{x} outside valid range of #{range_first}..#{range_last}\n"
            end
          end
        end # end each column
      end # end each row
      result
    end

    def table_default(table_name)
      raise "Please open a table first." unless @config
      set_binary_data_to_default(table_name)
    end

    # option to display a dialog containing a hex dump of the current table values
    def table_hex(table_name)
      raise "Please open a table first." unless @config
      table = @config.table(table_name)
      raise "Please open a table first." unless table
      "#{table.buffer.formatted}\n\nTotal Bytes Read: #{table.buffer.length}"
    end

    # option to save the currently displayed table as a stand alone binary file
    def table_save(table_name, filename)
      raise "Please open a table first." unless @config
      table_check(table_name)

      File.open(filename, 'wb') do |file|
        file.write(@config.get_table(table_name).buffer)
      end
    end

    # option to save the currently displayed table to an existing table binary file
    # containing that table.
    def table_commit(table_name, bin_file, def_file)
      raise "Please open a table first." unless @config
      save_table = @config.get_table(table_name)
      raise "Please open a table first." unless save_table

      result = file_check()
      unless result.empty?
        raise "Please fix the following errors before saving:\n\n" << result
      end

      @binary_file = bin_file
      @definition_file = def_file

      parser = TableConfig.new
      begin
        parser.process(def_file)
      rescue => err
        raise "The table definition file:#{def_file} has the following errors:\n#{err}"
      end

      if !parser.get_table_names.include?(table_name)
        raise "#{table_name} not found in #{def_file} table definition file."
      end

      @config = parser
      open_and_load_binary_file(bin_file)

      # Store the saved table data in the new table definition
      table = @config.get_table(save_table.name)
      table.buffer = save_table.buffer[0...table.length]
      file_save(bin_file)
    end

    # Updates the definition file for a table.
    def table_update_def(table_name)
      raise "Please open a table first." unless @config

      # Check to see that the table definition file is writeable
      table = @config.get_table(table_name)
      raise "Please open a table first." unless table

      if !File.writable?(table.filename)
        raise "#{table.filename} is not writeable."
      end

      # Check for errors in the table before updating the defaults
      result = table_check(table_name)
      unless result.empty?
        raise "Please fix the following errors before updating the definition file:\n\n" << result
      end

      begin
        @config.commit_default_values(table)
      rescue => err
        raise "The table definition file could not be written due to the following error(s):\n#{err}"
      end
    end

    # Return a GenericTable given a String table name
    def get_table(table_name)
      @config.table(table_name)
    end

    # Retrieves a value from a table
    def get_table_item(table_name, item_name)
      @config.table(table_name).read(item_name)
    end

    # Updates a value in a table
    def set_table_item(table_name, item_name, value)
      @config.table(table_name).write(item_name, value)
    end

    # Determines the string representation of an item as it should be printed in a RPT file
    def item_to_report_string(table, table_item)
      result = ""
      case table_item.display_type
      when :NONE
        result = "\n#{table.read(table_item.name).formatted}"
      when :STATE, :DEC, :STRING
        result = table.read(table_item.name).to_s
      when :CHECK
        value = table.read(table_item.name)
        if value == table_item.range.end
          result = "X (#{table_item.range.end.to_s})"
        else
          result = "- (#{table_item.range.begin.to_s})"
        end
      when :HEX
        result = @config.format_hex(table, table_item)
      end
      result
    end

    protected

    # Set all the binary data in the table to the default values
    def set_binary_data_to_default(table_name)
      table = @config.table(table_name)
      return unless table
      table.restore_defaults
    end

    def def_to_bin_filename(definition_filename)
      if File.basename(definition_filename) =~ /_def\.txt$/
        # Remove _def.txt if present (should be)
        basename = File.basename(definition_filename)[0...-8]
      else
        # Remove any extension if present
        basename = File.basename(definition_filename, File.extname(definition_filename))
      end
      "#{basename}.dat"
    end

    # Opens the given binary file and populates the table definition.
    # The filename parameter should be a properly formatted file path.
    def open_and_load_binary_file(filename)
      begin
        data = nil
        # read the binary file and store it into an array
        File.open(filename, 'rb') do |file|
          data = file.read
        end
      rescue => err
        raise "Unable to open and load #{filename} due to #{err}."
      end

      binary_data_index = 0
      total_table_length = 0
      @config.get_all_tables.each {|table| total_table_length += table.length }
      @config.get_all_tables.each do |table|
        if binary_data_index + table.length > data.length
          table.buffer = data[binary_data_index..-1]
          raise "Binary size of #{data.length} not large enough to fully represent table definition of length #{total_table_length}. The remaining table definition (starting with byte #{data.length - binary_data_index} in #{table.name}) will be filled with 0."
        end
        table.buffer = data[binary_data_index...binary_data_index+table.length]
        binary_data_index += table.length
      end
      if binary_data_index < data.length
        raise "Binary size of #{data.length} larger than table definition of length #{total_table_length}. Discarding the remaing #{data.length - binary_data_index} bytes."
      end
    end

  end

end # module Cosmos
