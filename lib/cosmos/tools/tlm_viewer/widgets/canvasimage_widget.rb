# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/canvas_clickable'

module Cosmos
  # Displays an image on a canvas. The image is loaded from file first by
  # looking in the target's screens directory and then the COSMOS data path.
  class CanvasimageWidget
    include Widget
    include CanvasClickable

    def initialize(parent_layout, filename, x, y)
      super()
      @x = x.to_i
      @y = y.to_i
      @filename = filename
      @image = nil
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.drawImage(@x, @y, @image) if @image
    end

    def dispose
      super()
      @image.dispose
    end

    def process_settings
      super
      # We wait until here to find the image because we need @screen to be set
      # to determine the target name to look in the target's screens directory
      @image = get_image(@filename)
      @x_end = @x + @image.width
      @y_end = @y + @image.height
    end
  end
end
