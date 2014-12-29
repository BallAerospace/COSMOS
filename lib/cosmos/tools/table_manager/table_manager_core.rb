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
    # the currently opened definition file
    attr_reader :current_def

    # the currently opened binary file
    attr_reader :current_bin

    # an instance of TableDefinition
    attr_reader :table_def

    def initialize
      reset()
    end

    def reset
      @current_bin = nil
      @current_def = nil
      @table_def = nil
    end

    def process_definition(filename)
      @table_def = TableConfig.new()
      @table_def.process(filename)
    end

    # INTERFACE METHODS

    # Creates new binary files based on a list of definition files and an destination directory
    def file_new(def_files, output_dir, bar = nil)
      bin_files = []
      begin
        progress = 0.0
        progress_increment = 100.0 / def_files.length.to_f / 4.0

        def_files.each do |def_file|
          @current_def = def_file

          process_definition(def_file)
          if bar
            progress += progress_increment
            bar.progress = progress.to_i
          end

          # Initialize all values to defaults
          @table_def.get_all_tables.each do |table|
            set_binary_data_to_default(table.name)
          end

          if bar
            progress += progress_increment
            bar.progress = progress.to_i
          end

          # Now verify the tables makes sense as defined by the table definition.
          # It's possible to have a definition file with default values outside
          # the allowable range so we check for that here.
          result = file_check()
          unless result.empty?
            reset()
            raise "The table definition file has incompatibilities. Please fix the following errors:\n\n" << result
          end

          if bar
            progress += progress_increment
            bar.progress = progress.to_i
          end

          if File.basename(def_file) =~ /_def\.txt/
            basename = File.basename(def_file)[0...-8] # Get the basename without the _def.txt
          else
            basename = File.basename(def_file).split('.')[0...-1].join('.') # Get the basename without the extension
          end

          # Set the current_bin so the file_report function works correctly
          @current_bin = File.join(output_dir, "#{basename}.dat")
          file_save(@current_bin)
          bin_files << @current_bin
          if bar
            progress += progress_increment
            bar.progress = progress.to_i
          end
          file_report()
        end

        bar.progress = 100 if bar
        sleep(0.5)
      ensure
        reset()
      end
      return bin_files
    end

    # Opens a specified binary file using a specified definition file as the interpreter
    def file_open(def_file, bin_file)
      @current_bin = bin_file
      @current_def = def_file
      process_definition(def_file)
      open_and_load_binary_file(bin_file)
    end

    def file_save(filename = nil)
      raise "Please open a table first." unless @table_def
      @current_bin = filename if filename

      result = file_check()
      unless result.empty?
        raise "Please fix the following errors before saving:\n\n" << result
      end

      # Call the user defined function on_save to allow additional processing
      # before the file is written out
      on_save()

      File.open(@current_bin, "wb") do |file|
        @table_def.get_all_tables.each do |table|
          file.write(table.buffer)
        end
      end
    end

    def file_check
      raise "Please open a table first." unless @table_def

      result = ""
      @table_def.get_all_tables.each do |table|
        table_result = table_check(table.name)
        unless table_result.empty?
          result << "Error(s) in #{table.name}:\n" + table_result
        end
      end

      return result
    end

    def file_hex
      raise "Please open a table first." unless @table_def

      data = ""
      # collect the data from each table
      @table_def.get_all_tables.each do |table|
        data << table.buffer
      end

      str, size = create_hex_string(data)
      str << "\n\nTotal Bytes Read: %d" % size

      return str
    end

    # Generate the RPT file for the currently opened file
    def file_report
      raise "Please open a table first." unless @table_def

      result = file_check()
      unless result.empty?
        raise "Please fix the following errors before generating the report:\n\n" << result
      end

      filename = File.basename(@current_bin, ".dat")
      File.open(File.join(File.dirname(@current_bin), "#{filename}.rpt"), 'w+') do |file|
        file.write("File Definition: #{@current_def}\n")
        file.write("File Binary: #{@current_bin}\n\n")
        @table_def.get_all_tables.each do |table|
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
                item_def = items[c + r * table.num_columns]
              else
                item_def = items[r]
              end
              value = item_to_report_string(table, item_def)

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
                item_def = items[c + r * table.num_columns]
              else
                item_def = items[r]
              end

              value = item_to_report_string(table, item_def)

              file.printf("%-#{column_lengths[c+1]}s ", value)

            end
            file.write("\n") # newline after each row
          end
          file.write("\n") # newline after each table
        end # end @table_def.get_all_tables.each do |table|
      end
    end

    def table_check(table_name)
      raise "Please open a table first." unless @table_def

      table = @table_def.get_table(table_name)
      raise "Please open a table first." unless table

      result = ""
      item_defs = table.sorted_items

      # Check the ranges and constraints for each item in the table
      # We go through it this way (by row and columns) so we can grab the actual
      # user input when we display any errors found
      (0...table.num_rows).each do |r|
        (0...table.num_columns).each do |c|
          # get the table item definition so we know how to save it
          item_def = item_defs[r * table.num_columns + c]

          # if a constraint was defined call it here
          # this should set the underlying constraints
          if (item_def.constraint != nil)
            item_def.constraint.call(item_def, table, table.buffer)
          end

          x = table.read(item_def.name, :RAW)
          unless item_def.range.nil?
            if item_def.display_type == :STRING
              if x.length > item_def.range.last || x.length < item_def.range.first
                result << "  #{item_def.name}: #{x} must be between #{item_def.range.first} and #{item_def.range.last} characters\n"
              end
            else
              # check to see if the value lies within its valid range
              if not item_def.range.include?(x)
                # if the value is displayed as hex, display the range as hex
                if item_def.display_type == :HEX
                  range_first = "0x%X" % item_def.range.first
                  range_last = "0x%X" % item_def.range.last
                  x = "0x%X" % x
                else
                  range_first = item_def.range.first
                  range_last = item_def.range.last
                  x = table.read(item_def.name)
                end
                result << "  #{item_def.name}: #{x} outside valid range of #{range_first}..#{range_last}\n"
              end
            end
          end
        end # end each column
      end # end each row
      return result
    end

    def table_default(table_name)
      raise "Please open a table first." unless @table_def
      set_binary_data_to_default(table_name)
    end

    # option to display a dialog containing a hex dump of the current table values
    def table_hex(table_name)
      raise "Please open a table first." unless @table_def
      table = @table_def.get_table(table_name)
      raise "Please open a table first." unless table

      data = table.buffer
      str, size = create_hex_string(data)
      str << "\n\nTotal Bytes Read: %d" % size

      return str
    end

    # option to save the currently displayed table as a stand alone binary file
    def table_save(table_name, filename)
      raise "Please open a table first." unless @table_def

      result = table_check(table_name)
      unless result.empty?
        raise "Please fix the following errors before saving:\n\n" << result
      end

      File.open(filename, 'wb') do |datafile|
        table = @table_def.get_table(table_name)
        datafile.write(table.buffer)
      end
    end

    # option to save the currently displayed table to an existing table binary file
    # containing that table.
    def table_commit(table_name, bin_file, def_file)
      raise "Please open a table first." unless @table_def
      save_table = @table_def.get_table(table_name)
      raise "Please open a table first." unless save_table

      result = file_check()
      unless result.empty?
        raise "Please fix the following errors before saving:\n\n" << result
      end

      @current_bin = bin_file
      @current_def = def_file

      parser = TableConfig.new
      begin
        parser.process(def_file)
      rescue => err
        raise "The table definition file:#{def_file} has the following errors:\n#{err}"
      end

      if !parser.get_table_names.include?(table_name)
        raise "#{table_name} not found in #{def_file} table definition file."
      end

      @table_def = parser
      open_and_load_binary_file(bin_file)

      # Store the saved table data in the new table definition
      table = @table_def.get_table(save_table.name)
      table.buffer = save_table.buffer[0...table.length]
      file_save(bin_file)
    end

    # Updates the definition file for a table.
    def table_update_def(table_name)
      raise "Please open a table first." unless @table_def

      # Check to see that the table definition file is writeable
      table = @table_def.get_table(table_name)
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
        @table_def.commit_default_values(table)
      rescue => err
        raise "The table definition file could not be written due to the following error(s):\n#{err}"
      end
    end

    # Return a GenericTable given a String table name
    def get_table(table_name)
      @table_def.get_table(table_name)
    end

    # Retrieves a value from a table
    def get_table_item(table_name, item_name)
      @table_def.get_table(table_name).read(item_name)
    end

    # Updates a value in a table
    def set_table_item(table_name, item_name, value)
      @table_def.get_table(table_name).write(item_name, value)
    end

    # Override on_save to perform additional actions before the file is
    # saved to disk.
    def on_save
      return
    end

    # Determines the string representation of an item as it should be printed in a RPT file
    def item_to_report_string(table, item_def)
      result = ""
      case item_def.display_type
      when :NONE
        result = "\n#{table.read(item_def.name).formatted}"
      when :STATE, :DEC, :STRING
        result = table.read(item_def.name).to_s
      when :CHECK
        value = table.read(item_def.name)
        if value == item_def.range.end
          result = "X (#{item_def.range.end.to_s})"
        else
          result = "- (#{item_def.range.begin.to_s})"
        end
      when :HEX
        result = @table_def.format_hex(table, item_def)
      end

      return result
    end

    # Create a hex string representation of the given binary data string
    def create_hex_string(data)
      index = 0
      str = ""
      while index < data.length
        # after 16 bytes insert a newline in the display
        if index % 16 == 0
          # don't insert a newline the first time
          if index != 0
            str << "\n"
          end
          str << "0x%08X: " % index
        # every 4 bytes insert a space for readability
        elsif index % 4 == 0
          str << " "
        end
        str << "%02X" % data.getbyte(index)
        index += 1
      end
      return str, index
    end

    # Set all the binary data in the table definition to the default values
    def set_binary_data_to_default(table_name)
      table = @table_def.get_table(table_name)

      # if we can't find the table do nothing
      return unless table

      table.sorted_items.each do |item_def|
        if item_def.data_type == :BLOCK
          table.write(item_def.name, item_def.default.hex_to_byte_string)
        else
          table.write(item_def.name, item_def.default)
        end
      end
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
      @table_def.get_all_tables.each {|table| total_table_length += table.length }
      @table_def.get_all_tables.each do |table|
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
