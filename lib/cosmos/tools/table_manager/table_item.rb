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
  # Implements the attributes that are unique to a TableItem such as editable
  # and hidden. All other functionality is inherited from {PacketItem}.
  class TableItem < PacketItem
    # @return [Boolean] Whether this item is editable
    attr_reader :editable
    # @return [Boolean] Whether this item is hidden (not displayed)
    attr_reader :hidden

    # (see PacketItem#initialize)
    def initialize(name, bit_offset, bit_size, data_type, endianness, array_size = nil, overflow = :ERROR)
      super(name, bit_offset, bit_size, data_type, endianness, array_size, overflow)
      @display_type = nil
      @editable = true
      @hidden = false
    end

    # @param editable [Boolean] Whether this item can be edited
    def editable=(editable)
      raise ArgumentError, "#{@name}: editable must be a boolean but is a #{editable.class}" unless !!editable == editable
      @editable = editable
    end

    # @param hidden [Boolean] Whether this item should be hidden
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

    # Create a hash of this item's attributes
    def to_hash
      hash = super()
      hash['editable'] = self.editable
      hash['hidden'] = self.hidden
      hash
    end
  end
end
