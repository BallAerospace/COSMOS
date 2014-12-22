# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/opengl/texture_mapped_sphere'

module Cosmos

  class EarthModel < TextureMappedSphere
    def initialize(x, y, z)
      super(x, y, z, File.join(::Cosmos::PATH, 'data', 'EarthMap1024x512.gif'))
    end
  end

end # module Cosmos
