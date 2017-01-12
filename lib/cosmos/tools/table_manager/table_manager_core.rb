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
    class CoreError < StandardError; end
    # Raised when opening a file that is either larger or smaller than its definition
    class MismatchError < CoreError; end
    # Raised when there is no current table configuration
    class NoConfigError < CoreError
      def message
        "No current table configuration"
      end
    end
    # Raised when there is no table in the current configuration
    class NoTableError < CoreError
      def message
        "Table does not exist in current configuration"
      end
    end

    # @return [TableConfig] Configuration instance
    attr_reader :config

    def initialize
      reset()
    end

    def reset
      @config = nil
    end

    # @param filename [String] Create a new TableConfig instance and process the filename
    def process_definition(filename)
      @config = TableConfig.new()
      @config.process_file(filename)
    end

    # @param def_path [String] Definition file to process
    # @param output_dir [String] Output directory to create the new file
    # @return [String] Binary file path
    def file_new(def_path, output_dir)
      progress = 0.0
      process_definition(def_path)
      yield 0.3 if block_given?

      @config.table_names.each {|table_name| set_binary_data_to_default(table_name) }
      yield 0.7 if block_given?

      bin_path = File.join(output_dir, def_to_bin_filename(def_path))
      file_save(bin_path)
      bin_path
    end

    # @param bin_path [String] Binary file to open
    # @param def_path [String] Definition file to use when opening
    def file_open(bin_path, def_path)
      process_definition(def_path)
      open_and_load_binary_file(bin_path)
    end

    # Saves the current tables in the config instance to the given filename.
    #
    # @param [String] Filename to write, overwritten if it exists.
    def file_save(filename)
      raise NoConfigError unless @config
      file_check()
      File.open(filename, "wb") do |file|
        @config.tables.each do |table_name, table|
          file.write(table.buffer)
        end
      end
      file_report(filename, @config.filename)
    end

    # @return [String] Success string if parameters all check. Raises
    #   a CoreError if errors are found.
    def file_check
      raise NoConfigError unless @config
      result = ""
      @config.table_names.each do |name|
        table_result = table_check(name)
        unless table_result.empty?
          result << "Errors in #{name}:\n" + table_result
        end
      end
      raise CoreError, result unless result.empty?
      "All parameters are within their constraints."
    end

    # Create a CSV report file based on the file contents.
    #
    # @param [String] Binary filename currently open. Used to generate the
    #   report name such that it matches the binary filename.
    # @return [String] Report filename path
    def file_report(bin_path, def_path)
      raise NoConfigError unless @config
      file_check()

      basename = File.basename(bin_path, ".dat")
      report_path = File.join(File.dirname(bin_path), "#{basename}.csv")
      File.open(report_path, 'w+') do |file|
        file.write("File Definition, #{def_path}\n")
        file.write("File Binary, #{bin_path}\n\n")
        @config.tables.values.each do |table|
          items = table.sorted_items
          file.puts(table.table_name)

          # Write the column headers
          if table.type == :TWO_DIMENSIONAL
            columns = ["Item"]
            # Remove the '0' from the 'itemname0'
            table.num_columns.times.each {|x| columns << items[x].name[0...-1] }
            file.puts columns.join(", ")
          else
            file.puts "Label, Value"
          end

          # Write the table item values
          (0...table.num_rows).each do |r|
            if table.type == :TWO_DIMENSIONAL
              rowtext = "#{r + 1}"
            else
              rowtext = items[r].name
            end

            file.write "#{rowtext}, "
            (0...table.num_columns).each do |c|
              if table.type == :TWO_DIMENSIONAL
                table_item = items[c + r * table.num_columns]
              else
                table_item = items[r]
              end

              file.write "#{table.read(table_item.name, :FORMATTED).to_s}, "
            end
            file.write("\n") # newline after each row
          end
          file.write("\n") # newline after each table
        end
      end
      report_path
    end

    # Create a hex formatted string of all the file data
    def file_hex
      raise NoConfigError unless @config
      data = ""
      @config.tables.values.each {|table| data << table.buffer }
      "#{data.formatted}\n\nTotal Bytes Read: #{data.length}"
    end

    # @param table_name [String] Name of the table to check for out of range values
    def table_check(table_name)
      raise NoConfigError unless @config
      table = @config.table(table_name)
      raise NoTableError unless table

      result = ""
      table_items = table.sorted_items

      # Check the ranges and constraints for each item in the table
      # We go through it this way (by row and columns) so we can grab the actual
      # user input when we display any errors found
      (0...table.num_rows).each do |r|
        (0...table.num_columns).each do |c|
          # get the table item definition so we know how to save it
          table_item = table_items[r * table.num_columns + c]

          value = table.read(table_item.name)
          unless table_item.range.nil?
            # If the item has states which include the value, then convert
            # the state back to the numeric value for range checking
            if table_item.states && table_item.states.include?(value)
              value = table_item.states[value]
            end
            # check to see if the value lies within its valid range
            unless table_item.range.include?(value)
              if table_item.format_string
                value = table.read(table_item.name, :FORMATTED)
                range_first = sprintf(table_item.format_string, table_item.range.first)
                range_last = sprintf(table_item.format_string, table_item.range.last)
              else
                range_first = table_item.range.first
                range_last = table_item.range.last
              end
              result << "  #{table_item.name}: #{value} outside valid range of #{range_first}..#{range_last}\n"
            end
          end
        end # end each column
      end # end each row
      result
    end

    # @param table_name [String] Name of the table to revert all values to default
    def table_default(table_name)
      raise NoConfigError unless @config
      set_binary_data_to_default(table_name)
    end

    # @param table_name [String] Create a hex formatted string of the given table data
    def table_hex(table_name)
      raise NoConfigError unless @config
      table = @config.table(table_name)
      raise NoTableError unless table
      "#{table.buffer.formatted}\n\nTotal Bytes Read: #{table.buffer.length}"
    end

    # @param table_name [String] Table name to write as a stand alone file
    # @param filename [String] Filename to write the table data to. Existing
    #   files will be overwritten.
    def table_save(table_name, filename)
      raise NoConfigError unless @config
      result = table_check(table_name)
      raise CoreError, "Errors in #{table_name}:\n#{result}" unless result.empty?
      File.open(filename, 'wb') {|file| file.write(@config.table(table_name).buffer) }
    end

    # Commit a table from the current configuration into a new binary
    #
    # @param table_name [String] Table name to commit to an existing binary
    # @param bin_path [String] Binary file to open
    # @param def_path [String] Definition file to use when opening
    def table_commit(table_name, bin_file, def_file)
      raise NoConfigError unless @config
      save_table = @config.table(table_name)
      raise NoTableError unless save_table

      result = table_check(table_name)
      raise CoreError, "Errors in #{table_name}:\n#{result}" unless result.empty?

      config = TableConfig.new
      begin
        config.process_file(def_file)
      rescue => err
        raise CoreError, "The table definition file:#{def_file} has the following errors:\n#{err}"
      end

      if !config.table_names.include?(table_name.upcase)
        raise NoTableError, "#{table_name} not found in #{def_file} table definition file."
      end

      saved_config = @config
      @config = config
      open_and_load_binary_file(bin_file)

      # Store the saved table data in the new table definition
      table = config.table(save_table.table_name)
      table.buffer = save_table.buffer[0...table.length]
      file_save(bin_file)
      @config = saved_config
    end

    protected

    # Set all the binary data in the table to the default values
    def set_binary_data_to_default(table_name)
      table = @config.table(table_name)
      raise NoTableError unless table
      table.restore_defaults
    end

    # Get the binary filename equivalent for the given definition filename
    def def_to_bin_filename(def_path)
      if File.basename(def_path) =~ /_def\.txt$/
        # Remove _def.txt if present (should be)
        basename = File.basename(def_path)[0...-8]
      else
        # Remove any extension if present
        basename = File.basename(def_path, File.extname(def_path))
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
      @config.tables.each {|table_name, table| total_table_length += table.length }
      @config.tables.each do |table_name, table|
        if binary_data_index + table.length > data.length
          table.buffer = data[binary_data_index..-1]
          raise MismatchError, "Binary size of #{data.length} not large enough to fully represent table definition of length #{total_table_length}. The remaining table definition (starting with byte #{data.length - binary_data_index} in #{table.table_name}) will be filled with 0."
        end
        table.buffer = data[binary_data_index...binary_data_index + table.length]
        binary_data_index += table.length
      end
      if binary_data_index < data.length
        raise MismatchError, "Binary size of #{data.length} larger than table definition of length #{total_table_length}. Discarding the remaing #{data.length - binary_data_index} bytes."
      end
    end
  end
end # module Cosmos
