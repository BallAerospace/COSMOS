# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'csv'

module Cosmos
  # Reads in a comma separated values (CSV) configuration file and
  # allows access via the Hash bracket syntax. It allows the user to write
  # back data to the configuration file to store state.
  class CSV
    # @return [String] The name of the archive file
    attr_reader :archive_file

    # @param input_file [String] CSV file name to read
    def initialize(input_file)
      @filename = input_file
      @hash = {}
      @archive = nil
      @archive_file = ""
      Object::CSV.read(input_file).each do |line|
        @hash[line[0]] = line[1..-1]
      end
    end

    # @return [Array<String>] All the values in the first column of the CSV file.
    #   These values are used as keys to access the data in columns 2-n.
    def keys
      @hash.keys
    end

    # @return [Array<String>] The values in columns 2-n corresponding to the
    #   given key in column 1. The values are always returned as Strings so the
    #   user must convert if necessary.
    def [](index)
      @hash[index]
    end

    # Convenience method to access a value by key and convert it to a boolean.
    # The csv value must be 'TRUE' or 'FALSE' (case doesn't matter)
    # and will be converted to Ruby true or false values.
    #
    # @param item [String] Key to access the value
    # @param index [Integer] Which value to return
    # @return [Boolean] Single value converted to a boolean (true or false)
    def bool(item, index = 0)
      raise "#{item} not found" unless keys.include?(item)
      if Range === index
        @hash[item][index].map do |x|
          case x.upcase
          when 'TRUE'
            true
          when 'FALSE'
            false
          else
            raise "#{item} value of #{x} not boolean. Must be 'TRUE' 'or 'FALSE'."
          end
        end
      else
        case @hash[item][index].upcase
        when 'TRUE'
          true
        when 'FALSE'
          false
        else
          raise "#{item} value of #{@hash[item][index]} not boolean. Must be 'TRUE' 'or 'FALSE'."
        end
      end
    end
    alias boolean bool

    # Convenience method to access a value by key and convert it to an integer
    #
    # @param item [String] Key to access the value
    # @param index [Integer] Which value to return
    # @return [Integer] Single value converted to an integer
    def int(item, index = 0)
      raise "#{item} not found" unless keys.include?(item)
      if Range === index
        @hash[item][index].map {|x| x.to_i }
      else
        @hash[item][index].to_i
      end
    end
    alias integer int

    # Convenience method to access a value by key and convert it to a float
    #
    # @param item [String] Key to access the value
    # @param index [Integer] Which value to return
    # @return [Float] Single value converted to a float
    def float(item, index = 0)
      raise "#{item} not found" unless keys.include?(item)
      if Range === index
        @hash[item][index].map {|x| x.to_f }
      else
        @hash[item][index].to_f
      end
    end

    # Convenience method to access a value by key and convert it to a string
    #
    # @param item [String] Key to access the value
    # @param index [Integer] Which value to return
    # @return [String] Single value converted to a string
    def string(item, index = 0)
      raise "#{item} not found" unless keys.include?(item)
      if Range === index
        @hash[item][index].map {|x| x.to_s }
      else
        @hash[item][index].to_s
      end
    end
    alias str string

    # Convenience method to access a value by key and convert it to a symbol
    #
    # @param item [String] Key to access the value
    # @param index [Integer] Which value to return
    # @return [Symbol] Single value converted to a symbol
    def symbol(item, index = 0)
      raise "#{item} not found" unless keys.include?(item)
      if Range === index
        @hash[item][index].map {|x| x.intern }
      else
        @hash[item][index].intern
      end
    end
    alias sym symbol

    # Creates a copy of the CSV file passed into the constructor. The file will
    # be prefixed by the current date and time to create a unique filename.
    # By default this file is created in the COSMOS/logs directory. Subsequent
    # calls to {#write_archive} will write to this file until {#close_archive}
    # is called.
    #
    # @param path [String] Path location to create the archive file. If nil the
    #   file will be created in COSMOS/logs.
    def create_archive(path = nil)
      close_archive() if @archive
      path = System.paths['LOGS'] if path.nil?

      attempt = nil
      while true
        name = File.build_timestamped_filename([File.basename(@filename, '.csv'), attempt], '.csv')
        @archive_file = File.join(path, name)
        if File.exist?(@archive_file)
          attempt ||= 0
          attempt += 1
        else
          break
        end
      end

      @archive = File.open(@archive_file, "w")
      @hash.each do |key, values|
        @archive.puts "#{key},#{values.join(',')}"
      end
      @archive.puts "\n"
    end

    # Write the archive file created by #{CSV#create_archive}. This method will
    # append a row to the archive file by joining writing the value.
    #
    # @param value [Objct|Array] Simply value to write to the end of the
    #   archive or array of values which will be written out as CSV
    def write_archive(value)
      create_archive() unless @archive
      if value.is_a? Array
        @archive.puts value.join(',')
      else
        @archive.puts value
      end
    end

    # Closes the archive file created by #{CSV#create_archive}.
    def close_archive
      @archive.close
      File.chmod(0444, @archive_file)
      @archive = nil
    end
  end
end
