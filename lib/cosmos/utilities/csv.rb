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
        @hash[line[0]] = line[1..-1].compact
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

    # Creates a copy of the CSV file passed into the constructor. The file will
    # be prefixed by the current date and time to create a unique filename.
    # By default this file is created in the COSMOS/logs directory. Subsequent
    # calls to {#write_archive} will write to this file until {#close_archive}
    # is called.
    #
    # @param path [String] Path location to create the archive file. If nil the
    #   file will be created in COSMOS/logs.
    def create_archive(path = nil)
      raise "Archive file \"#{@archive.path}\" already open." unless @archive.nil?
      path = System.paths['LOGS'] if path.nil?
      @archive_file = File.join(path, File.build_timestamped_filename([File.basename(@filename)], ''))
      @archive = File.open(@archive_file,"w")
      @hash.each do |key, values|
        @archive.puts "#{key},#{values.join(',')}"
      end
      @archive.puts "\n"
    end

    # Write the archive file created by #{CSV#create_archive}. This method will
    # append a CSV row to the archive file by joining all the values in the
    # array into a CSV entry.
    #
    # @param [Array] values Array of values which will go in columns 1-n
    def write_archive(values)
      raise "Archive file not opened! Call create_archive." if @archive.nil?
      @archive.puts values.join(',')
    end

    # Closes the archive file created by #{CSV#create_archive}. Once this method is
    # called, {#write_archive} will throw an exception.
    def close_archive
      @archive.close
      @archive = nil
    end

  end # class Csv
end
