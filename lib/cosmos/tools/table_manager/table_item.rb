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
    attr_reader :constraint

    # (see PacketItem#initialize)
    # It also initializes the attributes of the TableItem.
    def initialize(name, bit_offset, bit_size, data_type, endianness, array_size = nil, overflow = :ERROR)
      super(name, bit_offset, bit_size, data_type, endianness, array_size, overflow)
      @display_type = nil
      @editable = true
      @constraint = nil
    end

    def editable=(editable)
      raise ArgumentError, "#{@name}: editable must be a boolean but is a #{editable.class}" unless !!editable == editable
      @editable = editable
    end

    def constraint=(constraint)
      if constraint
        raise ArgumentError, "#{@name}: constraint must be a Conversion but is a #{constraint.class}" unless Cosmos::Conversion === constraint
        @constraint = constraint.clone
      else
        @constraint = nil
      end
    end

    # Make a light weight clone of this item
    def clone
      item = super()
      item.editable = self.editable
      item.constraint = self.constraint.clone if self.constraint
      item
    end
    alias dup clone

    def to_hash
      hash = super()
      hash['editable'] = self.editable
      if self.constraint
        hash['constraint'] = self.constraint.to_s
      else
        hash['constraint'] = nil
      end
      hash
    end

  end # class TableItem

end # module Cosmos
