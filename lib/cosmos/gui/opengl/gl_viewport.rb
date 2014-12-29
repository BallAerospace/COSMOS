# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class GlViewport
    attr_accessor :left
    attr_accessor :right
    attr_accessor :top
    attr_accessor :bottom
    attr_accessor :hither
    attr_accessor :yon
    attr_accessor :w
    attr_accessor :h

    def initialize
      @left=-1.0;
      @right=1.0;
      @top=1.0;
      @bottom=-1.0;
      @hither=0.1;
      @yon=1.0;
      @w=100;
      @h=100;
    end
  end # class Viewport

end # module Cosmos
