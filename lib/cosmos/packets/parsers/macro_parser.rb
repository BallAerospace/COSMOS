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
    def self.new_item
      return unless @macro
      @macro.new_item
    end

    # Starts a new Macro
    #
    # @param parser [ConfigParser] Configuration Parser
    def self.start(parser)
      if @macro
        @macro = nil
        raise parser.error("First close the previous MACRO_APPEND_START with a MACRO_APPEND_END")
      else
        @macro = MacroParser.new(parser)
      end
    end

    # Ends the Macro and adds all the items to the packet
    #
    # @param parser [ConfigParser] Configuration Parser
    # @param packet [Packet] Packet to add the macro items to
    def self.end(parser, packet)
      raise parser.error("First start a macro with MACRO_APPEND_START") unless @macro
      @macro.complete(packet)
    ensure
      # Ensure this class instance variable gets cleared so we can process the
      # next call to start
      @macro = nil
    end

    # @param parser [ConfigParser] Configuration Parser
    def initialize(parser)
      @parser = parser
      @usage = '#{keyword} <FIRST INDEX> <LAST INDEX> [NAME FORMAT]'
      parser.verify_num_parameters(2, 3, @usage)
      @macro = OpenStruct.new(:started => true, :list => [])
      first_index = parser.parameters[0].to_i
      last_index  = parser.parameters[1].to_i
      if first_index < last_index
        @macro.indices = (first_index..last_index).to_a
      else
        @macro.indices = (last_index..first_index).to_a.reverse
      end
      @macro.format = parser.parameters[2] ? parser.parameters[2] : '%s%d'
      @macro.format_order = get_format_order()
    end

    def new_item
      if @parser.keyword.include?('APPEND')
        @macro.list << @parser.parameters[0].upcase
      end
    end

    def complete(packet)
      @parser.verify_num_parameters(0, 0, @parser.keyword)
      raise @parser.error("Missing MACRO_APPEND_START before this config.line.", @parser.keyword) unless @macro
      raise @parser.error("No items appended in MACRO_APPEND list", @parser.keyword) if @macro.list.empty?

      create_new_packet_items(packet)
    end

    private

    def format_item_name(name, index)
      if @macro.format_order == 'sd'
        sprintf(@macro.format, name, index)
      else
        sprintf(@macro.format, index, name)
      end
    end

    def create_new_packet_items(packet)
      # Shift off the first macro index because since the first item(s) already exist we just rename
      first_index = @macro.indices.shift
      @macro.list.each do |name|
        original_item_name = name
        new_name = format_item_name(name, first_index)
        item = packet.rename_item(name, new_name)

        # The renaming indices create new items
        @macro.indices.each do |index|
          new_item = item.clone
          new_item.name = format_item_name(original_item_name, index)
          packet.append(new_item)
        end
      end
    end

    def get_format_order()
      string_index = @macro.format.index(/%\d*s/)
      num_index = @macro.format.index(/%\d*d/)
      raise parser.error("Invalid NAME FORMAT (#{@macro.format}) for MACRO_APPEND_START", @usage) unless string_index && num_index
      if string_index < num_index
        @macro.format_order = 'sd'
      else
        @macro.format_order = 'ds'
      end
    end

  end
end # module Cosmos
