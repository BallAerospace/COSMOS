# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/table_manager/table'

module Cosmos

  # TableConfig provides capabilities to read an ascii file that defines the
  # table parameters in a system and create a set of Tables for each.
  class TableConfig

    # Constructor for a TableConfig
    def initialize
      @ordered_tables = nil
      @tables = nil
      @current_name = nil
      @current_table = nil
      @current_parameter = nil
      @cur_bit_offset = 0
      @default_count = 0
      @item_definitions = nil
      @table_names = nil
    end

    # Processes a file and adds in the tables defined in the file
    def process(filename)
      building_generic_conversion = false
      converted_type = nil
      converted_bit_size = nil
      proc_text = ''

      Logger.info "Processing table config in file '#{filename}'"

      unless test ?f, filename
        Logger.error "File does not exist"
        raise "ERROR! Table config file #{filename} does not exist!"
      end

      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, parameters|
        next unless keyword
        if building_generic_conversion
          case keyword
          # Complete a generic conversion
          when 'GENERIC_READ_CONVERSION_END', 'GENERIC_WRITE_CONVERSION_END', 'CONSTRAINT_END'
            parser.verify_num_parameters(0, 0, keyword)
            @current_parameter.read_conversion =
              GenericConversion.new(proc_text,
                                    converted_type,
                                    converted_bit_size) if keyword.include? "READ"
            @current_parameter.write_conversion =
              GenericConversion.new(proc_text,
                                    converted_type,
                                    converted_bit_size) if keyword.include? "WRITE"
            @current_parameter.constraint =
              GenericConversion.new(proc_text,
                                    converted_type,
                                    converted_bit_size) if keyword.include? "CONSTRAINT"
            building_generic_conversion = false
          # Add the current config.line to the conversion being built
          else
            proc_text << parser.line << "\n"
          end # case keyword

        else # not building generic conversion

          case keyword
          # Start the definition of a generic conversion.
          # All config.lines following this config.line are considered part
          # of the conversion until an end of conversion marker is found
          when 'GENERIC_READ_CONVERSION_START', 'GENERIC_WRITE_CONVERSION_START', 'CONSTRAINT_START'
            usage = "#{keyword} <Converted Type (optional)> <Converted Bit Size (optional)>"
            parser.verify_num_parameters(0, 2, usage)
            proc_text = ''
            building_generic_conversion = true
            converted_type = nil
            converted_bit_size = nil
            if parameters[0]
              converted_type = parameters[0].upcase.intern
              raise parser.error("Invalid converted_type: #{converted_type}.") unless [:INT, :UINT, :FLOAT, :STRING, :BLOCK].include? converted_type
            end
            converted_bit_size = Integer(parameters[1]) if parameters[1]

          when 'TABLEFILE'
            parser.verify_num_parameters(1, 1, "#{keyword} <File name>")
            process(File.join(File.dirname(filename), parameters[0]))

          when 'TABLE'
            usage = "TABLE <Table Name> <Table Description> <ONE_DIMENSIONAL or TWO_DIMENSIONAL> <BIG_ENDIAN or LITTLE_ENDIAN> <Identifier>"
            parser.verify_num_parameters(5, nil, usage)
            begin
              # locals declared for readability
              name = parameters[0]
              description = parameters[1]
              type = read_table_type(parameters[2])
              endianness = read_endianness(parameters[3])
              if parameters[5].nil?
                table_id = Integer(parameters[4])
              else
                table_id = []
                parameters[4..-1].each {|parameter| table_id << Integer(parameter)}
              end

              start_new_table(name, description, type, endianness, table_id, filename)
            rescue ArgumentError => err
              raise parser.error("#{err.message} with #{keyword}.\nUSAGE: #{usage}")
            end

          when 'PARAMETER'
            usage = "PARAMETER <Parameter Name> <Parameter Description> <Data Type> <Bit Size> <Display Type> <Minimum Value> <Maximum Value> <Default Value - Only in ONE_DIMENTIONAL>"
            parser.verify_num_parameters(6, 8, usage)
            finish_parameter()
            if @current_table
              @current_table.num_rows += 1

              begin
                if @current_table.type == :TWO_DIMENSIONAL
                  parameters[0] = "#{parameters[0]}0"
                end
                # locals declared for readability
                name = parameters[0]
                if @current_table.items[name.upcase]
                  raise ArgumentError, "The name \"#{name}\" was already defined"
                end
                description = parameters[1]
                type = read_item_type(parameters[2])
                bit_size = parameters[3].to_i
                display_type, editable = read_display_type(parameters[4], type)
                if type == :BLOCK || type == :STRING
                  range = nil
                else
                  range = convert_to_range(parameters[5], parameters[6], type, bit_size)
                end
                if @current_table.type == :ONE_DIMENSIONAL
                  if type == :STRING
                    default = convert_to_type(parameters[5], type)
                  else
                    default = convert_to_type(parameters[7], type)
                  end
                else # TWO_DIMENSIONAL defaults are set by the DEFAULT keyword
                  default = 0
                end

                @current_parameter = @current_table.create_param(name, @cur_bit_offset,
                  bit_size, type, description, range, default, display_type, editable)
                @cur_bit_offset += parameters[3].to_i
              rescue ArgumentError => err
                raise parser.error("#{err.message} with #{keyword}.\nUSAGE: #{usage}")
              end
            end

          when 'STATE'
            usage = "STATE <Key> <Value>"
            parser.verify_num_parameters(2, 2, usage)
            begin
              # locals declared for readability
              state_name = parameters[0]
              state_value = convert_to_type(parameters[1], @current_parameter.data_type)

              @current_parameter.states ||= {}
              @current_parameter.states[state_name.upcase] = state_value
            rescue ArgumentError => err
              raise parser.error("#{err.message} with #{keyword}.\nUSAGE: #{usage}")
            end

          when 'DEFAULT'
            usage = "DEFAULT <Value1> <Value2> ... <ValueN>"
            # if this is our first default value for a TWO_DIMENSIONAL table
            # then we redefine the default values
            if @default_count == 0
              @item_definitions = Array.new(@current_table.sorted_items)
              index = 0
              @item_definitions.each do |item_def|
                set_item_default_value(item_def, parameters[index])
                index += 1
              end

              @current_table.num_rows = 1

            # more default values have been given so copy all the parameters from
            # the first row and reset the defaults
            else
              index = 0

              @item_definitions.each do |item_def|
                new_item = @current_table.duplicate_item(item_def,
                                                                @default_count,
                                                                @cur_bit_offset)
                @cur_bit_offset += item_def.bit_size
                set_item_default_value(new_item, parameters[index])
                index += 1
              end
              @current_table.num_rows += 1
            end # end else for if @default_count == 1

            @default_count += 1

          when 'POLY_READ_CONVERSION'
            parser.verify_num_parameters(2, nil, "#{keyword} <C0> ... <CX>")
            @current_parameter.read_conversion = PolynomialConversion.new(parameters[0..-1])

          when 'POLY_WRITE_CONVERSION'
            parser.verify_num_parameters(2, nil, "#{keyword} <C0> ... <CX>")
            @current_parameter.write_conversion = PolynomialConversion.new(parameters[0..-1])

          else
            unknown_keyword(parser, keyword, parameters)
          end # end case parameters[0]
        end # end else for generic conversion
      end # end loop

      # Handle last packet
      finish_table()

    ensure
      file.close if defined? file and file
    end

    # Sets the given item definition's default parameter to the default value
    # given. This function does conversions based on the display_type of the item.
    def set_item_default_value(item_def, default = nil)
      begin
        # If no default was passed use the definition default
        if default == nil
          default = item_def.default
        end
        if item_def.display_type == :STATE
          begin
            val = item_def.states.key(Integer(default))
          rescue
            val = default
          end
          @current_table.write(item_def.name, val)
          item_def.default = @current_table.read(item_def.name, :RAW)
        else
          item_def.default = convert_to_type(default, item_def.data_type)
        end
      rescue
        Logger.error "Setting #{item_def.name} to #{default} failed! Using #{item_def.range.first} for the default value."
        item_def.default = item_def.range.first
      end
    end

    # Classes extending table_definition should override this function to add
    # new keyword processing. Ensure super() is called after processing new
    # keywords so the default behavior of raising an ArgumentError is maintained.
    def unknown_keyword(parser, keyword, parameters)
      raise parser.error("Unknown keyword '#{keyword}'.", nil) if keyword
    end

    # Returns a specific Table
    def get_table(name)
      @tables[name]
    end

    # Returns an array of all the Tables in the definition file
    def get_all_tables
      @ordered_tables
    end

    # Returns an array of all the table names in the definition file
    def get_table_names
      @table_names
    end

    # Returns a default-value representation of an item to be printed in a DEF file
    def item_to_def_string(table, item_def)
      result = ""
      case item_def.display_type
      when :STATE
        if table.type == :ONE_DIMENSIONAL
          result = table.read(item_def.name, :RAW).to_s
        else
          result = table.read(item_def.name).to_s
        end
      when :DEC, :STRING, :NONE
        result = table.read(item_def.name).to_s
      when :CHECK
        result = table.read(item_def.name, :RAW).to_s
      when :HEX
        result = format_hex(table, item_def)
      end

      return result
    end

    # Update all default values in the definition file on disk with current values
    def commit_default_values(table)
      new_file_data = ""
      table_found = false
      default_count = 0
      table_parameters = []
      parser = ConfigParser.new
      parser.parse_file(table.filename) do |keyword, parameters|
        line = parser.line

        case keyword
        when 'TABLE'
          name = parameters[0].remove_quotes
          if name == table.name
            table_found = true
          else
            table_found = false
          end

        when 'PARAMETER'
          if table_found
            name = parameters[0].remove_quotes
            if table.type == :ONE_DIMENSIONAL
              item = table.get_item(name)

              # update the default value (in case the user tries to reset default values)
              item.default = table.read(name, :RAW)

              # determine what the new default value will look like as printed in the DEF file
              new_default = item_to_def_string(table, item)

              # scan to the beginning of the default value
              line_index = line.index(keyword) # skip to start of keyword
              line_index = line.index(parameters[0], line_index+keyword.length) # skip to start of first param
              (1..7).each do |index|
                line_index = line.index(parameters[index], line_index+parameters[index-1].length) # skip to start of next param
              end

              # rebuild the line in 3 parts:
              # everything up to the old default value
              # the new default value
              # everything after the old default value
              line = line[0...line_index] + new_default + line[(line_index+parameters[7].length)..-1]
            else
              table_parameters << name
            end
          end

        when 'DEFAULT'
          if table_found
            line_index = line.index(keyword)
            previous_word = keyword
            table_parameters.each_with_index do |param_name, index|
              item_name = "#{param_name}#{default_count}"
              item = table.get_item(item_name)

              # update the default value (in case the user tries to reset default values)
              item.default = table.read(item_name, :RAW)

              # determine what the new default value will look like as printed in the DEF file
              new_default = item_to_def_string(table, item)
              if new_default.index(" ")
                new_default = '"' + new_default + '"'
              end

              # scan to the beginning of the default value
              line_index = line.index(parameters[index], line_index+previous_word.length)

              # rebuild the line in 3 parts:
              # everything up to the old default value
              # the new default value
              # everything after the old default value
              line = line[0...line_index] + new_default + line[(line_index+parameters[index].length)..-1]

              # update previous_word so that we can find the next value
              previous_word = new_default
            end

            # count the row so that we know what the item_name is next time we see DEFAULT
            default_count += 1
          end
        end

        new_file_data << (line + "\n")

      end # end loop

      # ok, now replace the old def file with the new one
      File.open(table.filename, "w") do |file|
        file.puts new_file_data
      end
    end

#    # Return the entire table_definition file for the given table name as a string
#    def print_table(name)
#      tdef = @tables[name]
#      tstr = ""
#      if tdef.table_id.class != Array
#        tstr << "TABLE \"#{tdef.name}\" \"#{tdef.description}\" #{convert_table_type(tdef.type)} #{convert_endianness(tdef.get_endianness)} #{tdef.table_id}\n"
#      else
#        tstr << "TABLE \"#{tdef.name}\" \"#{tdef.description}\" #{convert_table_type(tdef.type)} #{convert_endianness(tdef.get_endianness)} #{tdef.table_id.join(' ')}\n"
#      end
#      if tdef.type == :ONE_DIMENSIONAL
#        tdef.sorted_items.each do |item|
#          tstr << create_item_string(item, tdef.type)
#        end
#      else # TWO_DIMENSIONAL
#        tdef.num_columns.times do |column|
#          item_def = tdef.sorted_items[column]
#          tstr << create_item_string(item_def, tdef.type)
#        end
#
#        index = 0
#        tdef.sorted_items.each do |item|
#          if index % tdef.num_columns == 0
#            tstr << "\n  DEFAULT "
#          end
#          case item.display_type
#            when :DEC
#              default = item.default
#            when :STATE
#              default = "\"#{item.default}\""
#            when :HEX
#              default = "0x#{item.default.to_s(16)}"
#          end
#          tstr << "#{default} "
#          index += 1
#        end
#      end # end else # TWO_DIMENSIONAL
#      tstr
#    end # end print_table(name)

    def format_hex(table, item_def)
      case item_def.bit_size
        when 8
          x = sprintf("%02X", table.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 4 digits
          x = /\w{2}$/.match(x)[0]
        when 16
          x = sprintf("%04X", table.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 4 digits
          x = /\w{4}$/.match(x)[0]
        else
          x = sprintf("%08X", table.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 8 digits
          x = /\w{8}$/.match(x)[0]
      end
      return "0x%X" % Integer("0x#{x}") # convert to Integer
    end

    #############################################################################
    protected
    #############################################################################

#    # helper function to print_table to get states, constraint, read_conversion,
#    # and write_conversion that may be associated with an item in the table
#    def create_item_string(item, type)
#      tstr = ""
#      case item.display_type
#      when :DEC
#        min = item.range.first
#        max = item.range.last
#        default = item.default
#      when :STATE
#        min = item.range.first
#        max = item.range.last
#        default = item.states[item.default]
#      when :HEX
#        min = "0x#{item.range.first.to_s(16)}"
#        max = "0x#{item.range.last.to_s(16)}"
#        default = "0x#{item.default.to_s(16)}"
#      end
#
#      name = item.name
#      display = convert_display_type(item.display_type, item.editable)
#      tstr << "  PARAMETER \"#{name}\" \"#{item.description}\" #{convert_item_type(item.data_type)} #{item.bit_size} #{display} #{min} #{max}"
#      if type == :ONE_DIMENSIONAL
#        tstr << " #{default}\n"
#      else # TWO_DIMENSIONAL
#        tstr << "\n"
#      end
#
#      if item.states
#        item.states.each do |key, value|
#          tstr << "    STATE \"#{key}\" #{value}\n"
#        end
#      end
#      if item.constraint
#        tstr << "    CONSTRAINT_START\n"
#        tstr << item.constraint.code
#        tstr << "    CONSTRAINT_END\n"
#      end
#      if item.read_conversion
#        if item.read_conversion.class == PolynomialConversion
#          tstr << "    POLY_READ_CONVERSION #{item.read_conversion.code}\n"
#        else
#          tstr << "    GENERIC_READ_CONVERSION_START\n"
#          tstr << item.read_conversion.code
#          tstr << "    GENERIC_READ_CONVERSION_END\n"
#        end
#      end
#      if not item.write_conversion.nil?
#        if item.write_conversion.class == PolynomialConversion
#          tstr << "    POLY_WRITE_CONVERSION #{item.write_conversion.code}\n"
#        else
#          tstr << "    GENERIC_WRITE_CONVERSION_START\n"
#          tstr << item.write_conversion.code
#          tstr << "    GENERIC_WRITE_CONVERSION_END\n"
#        end
#      end
#      tstr
#    end

    # Finish Updating parameter in packet
    def finish_parameter
      unless @current_parameter.nil?
        @current_table.set_item(@current_parameter)
      end
    end

    # Start processing a new packet
    def start_new_table(name, description, type, endianness, table_id, filename)
      finish_table
      @current_table = Table.new(name, description, type, endianness, table_id, filename)
      @current_name = name
      @default_count = 0
    end

    # Add current packet into hash if it exists
    def finish_table
      finish_parameter
      if @current_table
        Logger.info "finish_table #{@current_name}"
        if @current_table.num_rows
          if @tables.nil? or @table_names.nil? or @ordered_tables.nil?
            @tables = {}
            @table_names = []
            @ordered_tables = []
          end
          @tables[@current_name] = @current_table
          @table_names << @current_name
          @ordered_tables << @current_table
        end
        @current_table = nil
        @current_parameter = nil
        @cur_bit_offset = 0
      end
    end

    # Convert the table type string to a value
    def read_table_type(str)
      str.upcase!
      case str
      when 'ONE_DIMENSIONAL'
        :ONE_DIMENSIONAL
      when 'TWO_DIMENSIONAL'
        :TWO_DIMENSIONAL
      else
        raise ArgumentError, "Unknown table type:#{str}! Must be ONE_DIMENSIONAL or TWO_DIMENSIONAL"
      end
    end

    # Convert the table type value to a string
    def convert_table_type(type)
      case type
      when :ONE_DIMENSIONAL
        'ONE_DIMENSIONAL'
      when :TWO_DIMENSIONAL
        'TWO_DIMENSIONAL'
      else
        raise ArgumentError, "Unknown table type:#{type}!"
      end
    end

    # Convert the endianness string to a value
    def read_endianness(str)
      str.upcase!
      case str
      when 'BIG_ENDIAN'
        :BIG_ENDIAN
      when 'LITTLE_ENDIAN'
        :LITTLE_ENDIAN
      else
        raise ArgumentError, "Unknown endianness:#{str}! Must be BIG_ENDIAN or LITTLE_ENDIAN"
      end
    end

    # Convert the endianness value to a string
    def convert_endianness(endianness)
      case endianness
      when :BIG_ENDIAN
        'BIG_ENDIAN'
      when :LITTLE_ENDIAN
        'LITTLE_ENDIAN'
      else
        raise ArgumentError, "Unknown endianness:#{endianness}!"
      end
    end

    # Process a item type string into a value
    def read_item_type(str)
      str.upcase!
      case str
      when 'INT'
        :INT
      when 'UINT'
        :UINT
      when 'FLOAT'
        :FLOAT
      when 'STRING'
        :STRING
      when 'BLOCK'
        :BLOCK
      else
        raise ArgumentError, "Unknown type:#{str}! Must be INT, UINT, FLOAT, STRING, or BLOCK"
      end
    end

    # Process a item type value into a string
    def convert_item_type(type)
      case type
      when :INT
        'INT'
      when :UINT
        'UINT'
      when :FLOAT
        'FLOAT'
      when :STRING
        'STRING'
      when :BLOCK
        'BLOCK'
      else
        raise ArgumentError, "Unknown type:#{type}!"
      end
    end

    # Convert a string to the correct item type
    def convert_to_type(val, type)
      raise ArgumentError, "Value is not defined" if val.nil?
      begin
        case type
        when :INT, :UINT
          val = Integer(val)
        when :FLOAT
          val = Float(val)
        when :STRING, :BLOCK
          val = val.to_s
        end
      rescue
        begin
          val = eval(val)
        rescue
          case type
          when :INT
            type_name = 'INT'
          when :UINT
            type_name = 'UINT'
          when :FLOAT
            type_name = 'FLOAT'
          end
          raise ArgumentError, "Error evaluating value:#{val} of type:#{type_name}"
        end
      end
      val
    end

    # Convert the given minimum and maximum values of the given type and bit_size
    # into a valid Ruby range: min..max. The function verifies the range is not
    # backwards and that the minimum and maximum values make sense for the given
    # type and bit_size. For example, a maximum of 256 doesn't make sense for a UINT8.
    def convert_to_range(min, max, type, bit_size)
      min = ConfigParser.handle_defined_constants(min.convert_to_value, type, bit_size)
      max = ConfigParser.handle_defined_constants(max.convert_to_value, type, bit_size)
      range = min..max

      # First check for backwards ranges
      if min > max
        raise ArgumentError, "Min:#{min} can't be larger than max:#{max} in range"
      end

      case type
        # No case for FLOAT because if the type is a float the range
        # can be anything since you can't set a range wider than that allowed by a float
        when :UINT
          # First check for a negative range which doesn't make sense for UINT
          if min < 0 or max < 0
            raise ArgumentError, "Negative value in UINT range doesn't make sense"
          end
          if (bit_size == 8  and max > 255) or
             (bit_size == 16 and max > 65535) or
             (bit_size == 32 and max > 4294967295)
            raise ArgumentError, "Max value of #{max} in UINT range doesn't make sense"
          end
        when :INT
          if (bit_size == 8  and (min < -128 or max > 127)) or
             (bit_size == 16 and (min < -32768 or max > 32767)) or
             (bit_size == 32 and (min < -2147483648 or max > 2147483647))
            raise ArgumentError, "Max value of #{max} in INT range doesn't make sense"
          end
      end
      range
    end

    # Convert a display type string to the type value
    def read_display_type(display_type, value_type)
      editable = true
      display_type.upcase!

      if /-U/ =~ display_type
        editable = false
        display_type.sub!(/-U/,"")
      end

      case display_type
      when 'DEC'
        display_type = :DEC
      when 'HEX'
        display_type = :HEX
      when 'STATE'
        display_type = :STATE
      when 'CHECK'
        display_type = :CHECK
      when 'STRING'
        display_type = :STRING
      when 'NONE'
        display_type = :NONE
        editable = false
      else
        raise ArgumentError, "Unknown display type:#{display_type}! Must be DEC, DEC-U, HEX, HEX-U, STATE, STATE-U, CHECK, CHECK-U, STRING or NONE"
      end

      if value_type ==:STRING && display_type != :STRING
        raise ArgumentError, "STRING items must have a display type of STRING"
      end
      if value_type == :BLOCK && display_type != :NONE
        raise ArgumentError, "BLOCK items must have a display type of NONE"
      end

      return display_type, editable
    end

    # Convert display type value to a display type string
    def convert_display_type(type, editable)
      display =
      case type
      when :DEC
        'DEC'
      when :HEX
        'HEX'
      when :STATE
        'STATE'
      when :CHECK
        'CHECK'
      when :STRING
        'STRING'
      when :NONE
        'NONE'
      else
        raise ArgumentError, "Unkown display type:#{type}!"
      end
      if not editable
        display << "-U"
      end
      display
    end

  end # class TableConfig

end # module Cosmos
