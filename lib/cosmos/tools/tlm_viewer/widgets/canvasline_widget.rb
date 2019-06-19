# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # Draws a line on the canvas with an optional 'connector' (circle) on
  # the end of the line
  class CanvaslineWidget
    include Widget

    def initialize(parent_layout, x1, y1, x2, y2, color = 'black', width = 1, connector = 'NO_CONNECTOR')
      super()
      @x1 = x1.to_i
      @y1 = y1.to_i
      @x2 = x2.to_i
      @y2 = y2.to_i
      @point = Qt::Point.new(@x2, @y2)
      @width = width.to_i
      if connector.to_s.upcase == 'CONNECTOR'
        @connector = true
      else
        @connector = false
      end
      @color = Cosmos::getColor(color)
      @pen = Cosmos.getPen(color)
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.save
      @pen.setWidth(@width)
      painter.setPen(@pen)
      painter.drawLine(@x1, @y1, @x2, @y2)
      painter.drawLine(@x1, @y1, @x2, @y2)
      if (@connector == true)
        painter.setBrush(@color)
        painter.drawEllipse(@point, @width, @width)
      end
      painter.restore
    end

    def dispose
      super()
      @point.dispose
    end
  end
end
