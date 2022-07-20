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

require 'openc3/packets/packet_item'

module OpenC3
  # Implements the attributes that are unique to a TableItem such as editable
  # and hidden. All other functionality is inherited from {PacketItem}.
  class TableItem < PacketItem
    # @return [Boolean] Whether this item is editable
    attr_reader :editable

    # @return [Boolean] Whether this item is hidden (not displayed)
    attr_reader :hidden

    # (see PacketItem#initialize)
    def initialize(
      name,
      bit_offset,
      bit_size,
      data_type,
      endianness,
      array_size = nil,
      overflow = :ERROR
    )
      super(
        name,
        bit_offset,
        bit_size,
        data_type,
        endianness,
        array_size,
        overflow,
      )
      @display_type = nil
      @editable = true
      @hidden = false
    end

    # @param editable [Boolean] Whether this item can be edited
    def editable=(editable)
      unless !!editable == editable
        raise ArgumentError,
              "#{@name}: editable must be a boolean but is a #{editable.class}"
      end
      @editable = editable
    end

    # @param hidden [Boolean] Whether this item should be hidden
    def hidden=(hidden)
      unless !!hidden == hidden
        raise ArgumentError,
              "#{@name}: hidden must be a boolean but is a #{hidden.class}"
      end
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
    def as_json(*a)
      hash = super()
      hash['editable'] = self.editable
      hash['hidden'] = self.hidden
      hash
    end
  end
end
