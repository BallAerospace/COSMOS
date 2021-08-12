# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

require 'csv'

module Cosmos
  # Reads in a comma separated values (CSV) configuration file and
  # allows access via the Hash bracket syntax. It allows the user to write
  # back data to the configuration file to store state.
  class CSV
    # @return [String] The name of the archive file
    attr_reader :archive_file

    # @param input_file [String] CSV filename to read
    def initialize(input_file)
      @filename = input_file
      @hash = {}
      @archive = nil
      @archive_file = ""
      Object::CSV.read(input_file).each do |line|
        next if line[0].strip()[0] == '#' # Ignore Ruby comment lines

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
        @hash[item][index].map { |x| x.to_i }
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
        @hash[item][index].map { |x| x.to_f }
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
        @hash[item][index].map { |x| x.to_s }
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
        @hash[item][index].map { |x| x.intern }
      else
        @hash[item][index].intern
      end
    end
    alias sym symbol
  end
end
