# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  # Class holds a telemetry extractor configuration and controls writing to one output file
  class TlmExtractorConfig

    VALUE_TYPES = [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS]
    COLUMN_MODES = [:NORMAL, :SHARE_ALL_COLUMNS, :SHARE_INDIV_COLUMNS, :FULL_COLUMN_NAMES]
    DEFAULT_UNIQUE_IGNORED = ['RECEIVED_TIMEFORMATTED', 'RECEIVED_TIMESECONDS']
    ITEM = 'ITEM'.freeze
    TEXT = 'TEXT'.freeze

    attr_accessor :matlab_header
    attr_accessor :fill_down
    attr_reader :column_mode
    attr_accessor :unique_only
    attr_accessor :delimiter
    attr_accessor :downsample_seconds
    attr_accessor :print_filenames_to_output
    attr_reader :items
    attr_reader :shared_indiv_columns

    attr_accessor :output_filename
    attr_accessor :input_filenames

    def initialize(config_file = nil)
      @output_filename = nil
      @input_filenames = []
      @output_file = nil
      reset_settings()
      clear_items()
      clear_shared_columns()
      restore(config_file) if config_file
    end

    def reset_settings
      @matlab_header = false
      @fill_down = false
      @unique_only = false
      @delimiter = "\t"
      @unique_ignored = DEFAULT_UNIQUE_IGNORED.clone
      @downsample_seconds = 0.0
      @print_filenames_to_output = true
      set_column_mode(:NORMAL)
    end

    def clear_items
      @packet_to_column_mapping = {}
      @columns = []
      @columns_hash = {}
      @previous_row = nil
      @items = []
      @text_items = []
    end

    def add_item(target_name, packet_name, item_name, value_type = :CONVERTED)
      target_name = target_name.upcase
      packet_name = packet_name.upcase
      item_name = item_name.upcase

      raise "Unknown Value Type: #{value_type}" unless VALUE_TYPES.include?(value_type)

      hash_index = item_name + ' ' + value_type.to_s

      if @column_mode == :SHARE_ALL_COLUMNS and @columns_hash[hash_index]
        column_index = @columns_hash[hash_index]
      elsif @column_mode == :SHARE_INDIV_COLUMNS and @shared_indiv_columns.include?(hash_index) and @columns_hash[hash_index]
        column_index = @columns_hash[hash_index]
      else
        @columns << [item_name, value_type, nil, target_name, packet_name]
        column_index = @columns.length - 1
        @columns_hash[hash_index] = column_index
      end
      @packet_to_column_mapping[target_name] ||= {}
      @packet_to_column_mapping[target_name][packet_name] ||= []
      @packet_to_column_mapping[target_name][packet_name] << column_index
      @items << [ITEM, target_name, packet_name, item_name, value_type]
    end

    def add_text(column_name, text)
      @columns << [column_name, nil, nil, nil, nil]
      @items << [TEXT, column_name, text, nil, nil]
      @text_items << [@columns.length - 1, text]
    end

    def set_column_mode(mode)
      raise "Unknown Column Mode: #{mode}" unless COLUMN_MODES.include?(mode)

      @column_mode = mode
      if @column_mode != :SHARE_INDIV_COLUMNS
        clear_shared_columns()
      end
    end

    def clear_shared_columns()
      @shared_indiv_columns = []
    end

    def add_shared_column(item_name, value_type = :CONVERTED)
      raise "Unknown Value Type: #{value_type}" unless VALUE_TYPES.include?(value_type)

      shared_column_name = item_name + ' ' + value_type.to_s
      @shared_indiv_columns << shared_column_name
      @shared_indiv_columns.uniq!
    end

    def column_names
      if @column_mode == :FULL_COLUMN_NAMES
        col_offset = 0
        row = Array.new(@columns.length)
      else
        col_offset = 2
        row = Array.new(@columns.length + 2)
        row[0] = 'TARGET'
        row[1] = 'PACKET'
      end
      index = 0
      @columns.each do |column_name, column_value_type, item_data_type, target_name, packet_name|
        if @column_mode == :FULL_COLUMN_NAMES and target_name and packet_name
          column_name = [target_name, packet_name, column_name].join(' ')
        end
        case column_value_type
        when :CONVERTED, nil
          row[index + col_offset] = column_name
        else
          row[index + col_offset] = (column_name + '(' + column_value_type.to_s + ')')
        end
        index += 1
      end

      row
    end

    def restore(filename)
      Cosmos.set_working_dir do
        reset_settings()
        clear_items()

        parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#telemetry-extractor-configuration")
        parser.parse_file(filename) do |keyword, params|
          case keyword
          when 'DELIMITER'
            # Expect 1 parameter
            parser.verify_num_parameters(1, 1, "DELIMITER <Delimiter>")
            delimiter = params[0]
            if delimiter == "tab"
              delimiter = "\t"
            end
            @delimiter = delimiter

          when 'FILL_DOWN'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "FILL_DOWN")
            @fill_down = true

          when 'SHARE_COLUMNS'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "SHARE_COLUMNS")
            set_column_mode(:SHARE_ALL_COLUMNS)

          when 'SHARE_COLUMN'
            # Expect 1 or 2 parameters
            parser.verify_num_parameters(1, 2, "SHARE_COLUMN <Item Name> <Data Type (optional)>")
            item_name = params[0].upcase
            if params.length == 1
              value_type = :CONVERTED
            else
              value_type = params[1].upcase
              case value_type
              when 'CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'
                value_type = value_type.intern
              else
                raise "Unknown Value Type: #{value_type}"
              end
            end
            set_column_mode(:SHARE_INDIV_COLUMNS)
            add_shared_column(item_name, value_type)

          when 'FULL_COLUMN_NAMES'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "FULL_COLUMN_NAMES")
            set_column_mode(:FULL_COLUMN_NAMES)

          when 'UNIQUE_ONLY'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "UNIQUE_ONLY")
            @unique_only = true

          when 'UNIQUE_IGNORE'
            # Expect 1 parameter
            parser.verify_num_parameters(1, 1, "UNIQUE_IGNORE")
            @unique_ignored << params[0].upcase

          when 'DOWNSAMPLE_SECONDS'
            # Expect 1 parameter
            parser.verify_num_parameters(1, 1, "DOWNSAMPLE_SECONDS <Seconds>")
            @downsample_seconds = Float(params[0])

          when 'ITEM'
            # Expect 3 or 4 parameters
            parser.verify_num_parameters(3, 4, "ITEM <Target Name> <Packet Name> <Item Name> <Data Type (optional)>")
            target_name = params[0].upcase
            packet_name = params[1].upcase
            item_name = params[2].upcase
            if params.length == 3
              value_type = :CONVERTED
            else
              value_type = params[3].upcase
              case value_type
              when 'CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'
                value_type = value_type.intern
              else
                raise "Unknown Value Type: #{value_type}"
              end
            end
            add_item(target_name, packet_name, item_name, value_type)

          when 'TEXT'
            # Expect 2 parameters
            parser.verify_num_parameters(2, 2, "TEXT <Column Name> <Text>")
            add_text(params[0], params[1])

          when 'MATLAB_HEADER'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "MATLAB_HEADER")
            @matlab_header = true

          when 'DONT_OUTPUT_FILENAMES'
            # Expect 0 parameters
            parser.verify_num_parameters(0, 0, "DONT_OUTPUT_FILENAMES")
            @print_filenames_to_output = false

          else
            raise "Unknown keyword: #{keyword}"
          end
        end
      end
    end

    def save(filename)
      Cosmos.set_working_dir do
        File.open(filename, "w") do |file|
          if @fill_down
            file.puts 'FILL_DOWN'
          end
          if @matlab_header
            file.puts 'MATLAB_HEADER'
          end
          if !@print_filenames_to_output
            file.puts 'DONT_OUTPUT_FILENAMES'
          end
          if @column_mode == :SHARE_ALL_COLUMNS
            file.puts 'SHARE_COLUMNS'
          end
          if @column_mode == :SHARE_INDIV_COLUMNS
            @shared_indiv_columns.each do |shared_column|
              file.puts "SHARE_COLUMN #{shared_column}"
            end
          end
          if @column_mode == :FULL_COLUMN_NAMES
            file.puts 'FULL_COLUMN_NAMES'
          end
          if @unique_only
            file.puts 'UNIQUE_ONLY'
          end
          if @downsample_seconds != 0.0
            file.puts "DOWNSAMPLE_SECONDS #{@downsample_seconds}"
          end
          if @delimiter != "\t"
            file.puts "DELIMITER \"#{@delimiter}\""
          end
          if @unique_ignored != DEFAULT_UNIQUE_IGNORED
            @unique_ignored.each do |name|
              if !DEFAULT_UNIQUE_IGNORED.include?(name)
                file.puts "UNIQUE_IGNORE #{name}"
              end
            end
          end
          @items.each do |item_type, target_name_or_column_name, packet_name_or_text, item_name, value_type|
            if item_type == ITEM
              if value_type != :CONVERTED
                file.puts "#{item_type} #{target_name_or_column_name} #{packet_name_or_text} #{item_name} #{value_type}"
              else
                file.puts "#{item_type} #{target_name_or_column_name} #{packet_name_or_text} #{item_name}"
              end
            else
              file.puts "#{item_type} \"#{target_name_or_column_name}\" \"#{packet_name_or_text}\""
            end
          end
        end
      end # Cosmos.set_working_dir
    end

    def open_output_file
      # Reset per output state
      @row_index = 1
      @current_values = Array.new(@columns.length)
      @packet_timestamp_mapping = {}
      @previous_row = nil

      # Open the output file
      @output_file = File.open(@output_filename, 'w')

      if @print_filenames_to_output
        # Print input filenames to output file
        @input_filenames.each do |input_filename|
          if @matlab_header
            @output_file.puts "%#{input_filename}"
          else
            @output_file.puts input_filename
          end
          @row_index += 1
        end

        # Print blank row to output file
        if @matlab_header
          @output_file.puts "%"
        else
          @output_file.puts ""
        end
        @row_index += 1
      end

      # Print column headings to output file
      @output_file.print "%" if @matlab_header
      column_names().each do |column_name|
        @output_file.print column_name
        @output_file.print @delimiter
      end
      @output_file.puts ""
      @row_index += 1
    end

    def close_output_file
      begin
        @output_file.close if @output_file and !@output_file.closed?
      rescue
        # Oh well
      ensure
        @output_file = nil
      end
    end

    def process_packet(packet)
      changed = false
      target_mapping = @packet_to_column_mapping[packet.target_name]
      if target_mapping
        packet_mapping = target_mapping[packet.packet_name]
        if packet_mapping
          if @downsample_seconds != 0.0
            target_timestamp_mapping = @packet_timestamp_mapping[packet.target_name]
            unless target_timestamp_mapping
              @packet_timestamp_mapping[packet.target_name] = {}
              target_timestamp_mapping = @packet_timestamp_mapping[packet.target_name]
            end
            previous_timestamp = target_timestamp_mapping[packet.packet_name]
            return if previous_timestamp and (packet.received_time - previous_timestamp) < @downsample_seconds
            target_timestamp_mapping[packet.packet_name] = packet.received_time
          end

          # Create a new row
          if @fill_down and @previous_row
            row = @previous_row
          else
            row = Array.new(@columns.length)
          end

          # Add each packet item to the row
          packet_mapping.each do |column_index|
            column_name, column_value_type, item_data_type, target_name, packet_name = @columns[column_index]

            # Lookup item data type on first use
            unless item_data_type
              _, item = System.telemetry.packet_and_item(packet.target_name, packet.packet_name, column_name)
              item_data_type = item.data_type
              @columns[column_index] = [column_name, column_value_type, item_data_type, target_name, packet_name]
            end

            if item_data_type == :BLOCK
              case column_value_type
              when :RAW
                value = packet.read(column_name, :RAW).to_s.simple_formatted
                row[column_index] = value
                changed = true if @unique_only and @current_values[column_index] != value and !@unique_ignored.include?(column_name)
                @current_values[column_index] = value
              when :CONVERTED, :FORMATTED, :WITH_UNITS
                value = packet.read(column_name, :CONVERTED).to_s.simple_formatted
                row[column_index] = value
                changed = true if @unique_only and @current_values[column_index] != value and !@unique_ignored.include?(column_name)
                @current_values[column_index] = value
              end
            else
              value = packet.read(column_name, column_value_type)
              row[column_index] = value
              changed = true if @unique_only and @current_values[column_index] != value and !@unique_ignored.include?(column_name)
              @current_values[column_index] = value
            end
          end

          # Add text items to the row
          @text_items.each do |column_index, text|
            row[column_index] = text.gsub('%', @row_index.to_s)
          end

          if !@unique_only or changed
            # Output the row
            if @column_mode != :FULL_COLUMN_NAMES
              @output_file.print packet.target_name
              @output_file.print @delimiter
              @output_file.print packet.packet_name
            end
            row.each_with_index do |value, index|
              if @column_mode != :FULL_COLUMN_NAMES or index != 0
                @output_file.print @delimiter
              end
              @output_file.print value if value
            end
            @output_file.puts ""
            @row_index += 1
          end

          # Save previous row for handling fill_down
          @previous_row = row
        end # if packet_mapping
      end # if target_mapping
    end

  end # class TlmExtractorConfig

end # module Cosmos
