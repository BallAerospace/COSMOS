# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'

module Cosmos
  # Retrieves the result from an item processor
  class LimitsGroupConversion < Conversion
    def initialize(items)
      super()
      @items = items
    end

    # @param (see Conversion#call)
    # @return [Varies] The result of the associated processor
    def call(value, packet, buffer)
      _, limits = System.telemetry.values_and_limits_states(@items)
      val = 0
      limits.each do |limit|
        val = 1 if (val < 2 && (limit == :YELLOW || limit == :YELLOW_LOW || limit == :YELLOW_HIGH))
        val = 2 if (limit == :RED || limit == :RED_LOW || limit == :RED_HIGH)
      end
      val
    end

    # @return [String] The type of processor
    def to_s
      "LimitsGroupConversion"
    end
  end
end
