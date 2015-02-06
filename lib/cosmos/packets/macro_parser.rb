# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'ostruct'

module Cosmos
  class MacroParser

    # Adds a new item to the Macro
    #
    # @param parser [ConfigParser] Configuration Parser
    def self.new_item(parser)
      if parser.keyword.include?('APPEND')
        @macro_append.list << parser.parameters[0].upcase
      end
    end

    # @return [Boolean] Whether or not the macro has been started
    def self.started?
      @macro_append.nil? ? false : @macro_append.started
    end

    # Starts a new Macro
    #
    # @param parser [ConfigParser] Configuration Parser
    def self.start(parser)
      params = parser.parameters
      @macro_append = OpenStruct.new
      @macro_append.started = true
      @macro_append.list = []
      @macro_append.indices = []
      @macro_append.format = ''
      @macro_append.format_order = ''

      usage = '#{keyword} <FIRST INDEX> <LAST INDEX> [NAME FORMAT]'
      parser.verify_num_parameters(2, 3, usage)

      # Store the params
      first_index = params[0].to_i
      last_index  = params[1].to_i
      @macro_append.indices = [first_index, last_index].sort
      @macro_append.indices = (@macro_append.indices[0]..@macro_append.indices[1]).to_a
      @macro_append.indices.reverse! if first_index > last_index
      @macro_append.format  = params[2] ? params[2] : '%s%d'
      spos = @macro_append.format.index(/%\d*s/)
      dpos = @macro_append.format.index(/%\d*d/)
      raise parser.error("Invalid NAME FORMAT (#{@macro_append.format}) for MACRO_APPEND_START", usage) unless spos and dpos
      if spos < dpos
        @macro_append.format_order = 'sd'
      else
        @macro_append.format_order = 'ds'
      end
    end

    # Ends the Macro and adds all the items to the packet
    #
    # @param parser [ConfigParser] Configuration Parser
    # @param packet [Packet] Packet to add the macro items to
    def self.end(parser, packet)
      keyword = parser.keyword
      update_cache = false
      parser.verify_num_parameters(0, 0, keyword)
      raise parser.error("Missing MACRO_APPEND_START before this config.line.", keyword) unless @macro_append.started
      raise parser.error("No items appended in MACRO_APPEND list", keyword) unless @macro_append.list.length > 0

      # Get first index, remove from array
      first = @macro_append.indices.shift

      # Rename the items in the list using the first index
      items = packet.items
      @macro_append.list.each do |name|
        item = items[name]
        items.delete name
        if @macro_append.format_order == 'sd'
          first_name = sprintf(@macro_append.format, name, first)
        else
          first_name = sprintf(@macro_append.format, first, name)
        end
        item.name = first_name
        items[first_name] = item
      end

      # Append multiple copies of the items in the list
      @macro_append.indices.each do |index|
        @macro_append.list.each do |name|
          if @macro_append.format_order == 'sd'
            first_name = sprintf(@macro_append.format, name, first)
            this_name = sprintf(@macro_append.format, name, index)
          else
            first_name = sprintf(@macro_append.format, first, name)
            this_name = sprintf(@macro_append.format, index, name)
          end
          first_item = items[first_name]
          format_string = nil
          format_string = first_item.format_string if first_item.format_string
          this_item = packet.append_item(this_name,
                                                  first_item.bit_size,
                                                  first_item.data_type,
                                                  first_item.array_size,
                                                  first_item.endianness,
                                                  first_item.overflow,
                                                  format_string,
                                                  first_item.read_conversion,
                                                  first_item.write_conversion,
                                                  first_item.id_value)
          this_item.states = first_item.states if first_item.states
          this_item.description = first_item.description if first_item.description
          this_item.units_full = first_item.units_full if first_item.units_full
          this_item.units = first_item.units if first_item.units
          this_item.default = first_item.default
          this_item.range = first_item.range if first_item.range
          this_item.required = first_item.required
          this_item.hazardous = first_item.hazardous
          if first_item.state_colors
            this_item.state_colors = first_item.state_colors
            update_cache = true
          end
          if first_item.limits
            this_item.limits = first_item.limits
            update_cache = true
          end
        end
      end
      packet.update_limits_items_cache if update_cache

      @macro_append.started = false
      @macro_append.indices = []
      @macro_append.list = []
    end

  end
end # module Cosmos
