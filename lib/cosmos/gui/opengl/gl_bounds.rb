# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # Defines the boundary for a {GlScene}.
  class GlBounds
    def initialize(x0, x1, y0, y1, z0, z1)
      @x0 = x0
      @x1 = x1
      @y0 = y0
      @y1 = y1
      @z0 = z0
      @z1 = z1
    end

    # @param index [Integer] 0 based index into the bounds variables. Bounds
    #   are returned in the following order: x0, x1, y0, y1, z0, z1.
    # @return [Integer] Boundary value
    def [](index)
      case index
      when 0
        @x0
      when 1
        @x1
      when 2
        @y0
      when 3
        @y1
      when 4
        @z0
      when 5
        @z1
      else
        nil
      end
    end

    # @return [Array<Integer, Integer, Integer>] The center of the bounds
    def center
      [(@x0 + @x1) / 2.0, (@y0 + @y1) / 2.0, (@z0 + @z1) / 2.0]
    end

    # @return [Integer] The longest dimension of the bounds
    def longest
      [@x1 - @x0, @y1 - @y0, @z1 - @z0].max
    end
  end
end
