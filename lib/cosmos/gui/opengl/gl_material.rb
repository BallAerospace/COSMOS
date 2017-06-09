# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # Captures all the parameters associated with an OpenGL material
  class GlMaterial
    attr_accessor :ambient
    attr_accessor :diffuse
    attr_accessor :specular
    attr_accessor :emission
    attr_accessor :shininess

    def initialize
      @ambient = [0.2, 0.2, 0.2, 1.0]
      @diffuse = [0.8, 0.8, 0.8, 1.0]
      @specular = [1.0, 1.0, 1.0, 1.0]
      @emission = [0.0, 0.0, 0.0, 1.0]
      @shininess = 30.0;
    end
  end
end
