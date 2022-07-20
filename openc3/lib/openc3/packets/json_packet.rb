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
require 'json'
require 'openc3/config/config_parser'

module OpenC3
  class JsonPacket
    attr_accessor :cmd_or_tlm
    attr_accessor :target_name
    attr_accessor :packet_name
    attr_accessor :packet_time
    attr_accessor :stored
    attr_accessor :json_hash

    def initialize(cmd_or_tlm, target_name, packet_name, time_nsec_from_epoch, stored, json_data)
      @cmd_or_tlm = cmd_or_tlm.intern
      @target_name = target_name
      @packet_name = packet_name
      @packet_time = ::Time.from_nsec_from_epoch(time_nsec_from_epoch)
      @stored = ConfigParser.handle_true_false(stored)
      @json_hash = JSON.parse(json_data, :allow_nan => true, :create_additions => true)
    end

    # Read an item in the packet by name
    #
    # @param name [String] Name of the item to read - Should already by upcase
    # @param value_type (see #read_item)
    def read(name, value_type = :CONVERTED)
      if value_type == :WITH_UNITS
        value = @json_hash["#{name}__U"]
        return value if value
      end
      if value_type == :WITH_UNITS or value_type == :FORMATTED
        value = @json_hash["#{name}__F"]
        return value if value

        value = @json_hash["#{name}__C"]
        return value.to_s if value

        value = @json_hash[name]
        return value.to_s if value

        return nil
      end
      if value_type == :CONVERTED
        value = @json_hash["#{name}__C"]
        return value if value
      end
      value = @json_hash[name]
      return value if value
    end

    def read_with_limits_state(name, value_type = :CONVERTED)
      value = read(name, value_type)
      limits_state = @json_hash["#{name}__L"]
      limits_state.intern if limits_state
      return [value, limits_state]
    end

    # Read all items in the packet into an array of arrays
    #   [[item name, item value], ...]
    #
    # @param value_type (see #read_item)
    def read_all(value_type = :CONVERTED, names = nil)
      result = {}
      names = read_all_names() unless names
      names.each do |name|
        result[name] = read(name, value_type)
      end
      return result
    end

    # Read all items in the packet into an array of arrays
    #   [[item name, item value], [item limits state], ...]
    #
    # @param value_type (see #read_all)
    def read_all_with_limits_states(value_type = :CONVERTED, names = nil)
      result = {}
      names = read_all_names() unless names
      names.each do |name|
        result[name] = read_with_limits_state(name, value_type)
      end
      return result
    end

    # Read all the names of items in the packet
    # Note: This is not very efficient, ideally only call once for discovery purposes
    def read_all_names
      result = {}
      @json_hash.each do |key, value|
        result[key.split("__")[0]] = true
      end
      return result.keys
    end

    # Create a string that shows the name and value of each item in the packet
    #
    # @param value_type (see #read_item)
    # @param indent (see Structure#formatted)
    def formatted(value_type = :CONVERTED, names = nil, indent = 0)
      names = read_all_names() unless names
      indent_string = ' ' * indent
      string = ''
      names.each do |name|
        value = read(name, value_type)
        if String === value and value =~ File::NON_ASCII_PRINTABLE
          string << "#{indent_string}#{name}:\n"
          string << value.formatted(1, 16, ' ', indent + 2)
        else
          string << "#{indent_string}#{name}: #{value}\n"
        end
      end
      return string
    end
  end
end
