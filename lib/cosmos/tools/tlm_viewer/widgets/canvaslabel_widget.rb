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
  # Display text on the canvas of a given size and color
  class CanvaslabelWidget
    include Widget
    include CanvasClickable

    def initialize(parent_layout, x, y, text, font_size = 12, color = 'black')
      super()
      @x = x.to_i
      @paint_y = y.to_i
      @text = text
      @color = Cosmos::getColor(color)
      @font = Cosmos.getFont("helvetica", font_size.to_i)
      fm = Qt::FontMetrics.new(@font)
      @x_end = @x + fm.width(text)
      # drawText uses the y value as the bottom of the text
      # Thus for the clickable area we need to set the y_end to the y value
      # and calculate the top y value by subtracting the font height
      @y_end = y.to_i
      @y = @y_end - fm.height()
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.save
      painter.setPen(@color)
      painter.setFont(@font)
      painter.drawText(@x, @paint_y, @text)
      painter.restore
    end
  end
end
