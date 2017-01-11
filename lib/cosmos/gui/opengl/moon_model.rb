# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/opengl/texture_mapped_sphere'

module Cosmos
  # Three dimensional model of the moon by mapping a picture of the moon onto
  # a sphere.
  class MoonModel < TextureMappedSphere
    # @param x (see TextureMappedSphere#initialize)
    # @param y (see TextureMappedSphere#initialize)
    # @param z (see TextureMappedSphere#initialize)
    def initialize(x, y, z)
      super(x, y, z, File.join(::Cosmos::PATH, 'data', 'moonmap1k.gif'))
    end
  end
end
