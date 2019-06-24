# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # Display an ellipse on the canvas which can be filled or open
  class CanvasellipseWidget
    include Widget

    def initialize(parent_layout, center_x, center_y, width, height, color = 'black', line_width = 1, fill = false)
      super()
      @center_x = center_x.to_i
      @center_y = center_y.to_i
      @width = width.to_i
      @height = height.to_i
      @line_width = line_width.to_i
      @fill = ConfigParser::handle_true_false(fill)
      @color = Cosmos::getColor(color)
      @pen = Cosmos.getPen(color)
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.save
      @pen.setWidth(@line_width)
      painter.setPen(@pen)
      painter.setBrush(@color) if @fill
      painter.drawEllipse(@center_x, @center_y, @width, @height)
      painter.restore
    end
  end
end
