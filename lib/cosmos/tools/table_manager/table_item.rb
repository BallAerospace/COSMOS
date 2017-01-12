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
  # Maintains knowledge of an item in a Table
  class TableItem < PacketItem
    attr_reader :editable
    attr_reader :hidden

    # (see PacketItem#initialize)
    # It also initializes the attributes of the TableItem.
    def initialize(name, bit_offset, bit_size, data_type, endianness, array_size = nil, overflow = :ERROR)
      super(name, bit_offset, bit_size, data_type, endianness, array_size, overflow)
      @display_type = nil
      @editable = true
      @hidden = false
    end

    def editable=(editable)
      raise ArgumentError, "#{@name}: editable must be a boolean but is a #{editable.class}" unless !!editable == editable
      @editable = editable
    end

    def hidden=(hidden)
      raise ArgumentError, "#{@name}: hidden must be a boolean but is a #{hidden.class}" unless !!hidden == hidden
      @hidden = hidden
    end

    # Make a light weight clone of this item
    def clone
      item = super()
      item.editable = self.editable
      item
    end
    alias dup clone

    def to_hash
      hash = super()
      hash['editable'] = self.editable
      hash['hidden'] = self.hidden
      hash
    end
  end
end
