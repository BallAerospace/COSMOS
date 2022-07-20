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

require 'openc3/processors/processor'

module OpenC3
  class WatermarkProcessor < Processor
    # @param item_name [String] The name of the item to gather statistics on
    # @param value_type #See Processor::initialize
    def initialize(item_name, value_type = :CONVERTED)
      super(value_type)
      @item_name = item_name.to_s.upcase
      reset()
    end

    # Run watermarks on the item
    #
    # See Processor#call
    def call(packet, buffer)
      value = packet.read(@item_name, @value_type, buffer)
      high_water = @results[:HIGH_WATER]
      @results[:HIGH_WATER] = value if !high_water or value > high_water
      low_water = @results[:LOW_WATER]
      @results[:LOW_WATER] = value if !low_water or value < low_water
    end

    # Reset any state
    def reset
      @results[:HIGH_WATER] = nil
      @results[:LOW_WATER] = nil
    end

    # Convert to configuration file string
    def to_config
      "  PROCESSOR #{@name} #{self.class.name.to_s.class_name_to_filename} #{@item_name} #{@value_type}\n"
    end

    def as_json(*a)
      { 'name' => @name, 'class' => self.class.name, 'params' => [@item_name, @value_type.to_s] }
    end
  end # class WatermarkProcessor
end
