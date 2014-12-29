# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/canvasvalue_widget'

module Cosmos

  class CanvaslabelvalueWidget < CanvasvalueWidget

    def initialize(parent_layout, target_name, packet_name, item_name, x1, y1, font_size = 12, color = 'black', frame = true, frame_width = 3, value_type = :CONVERTED)
      super(parent_layout, target_name, packet_name, item_name, value_type)
      @x = x1.to_i
      @y = y1.to_i
      @color = Cosmos.getColor(color)
      @pen = Cosmos.getPen(color)
      @font = Cosmos.getFont("helvetica", font_size.to_i)
      @fm = Cosmos.getFontMetrics(@font)
      @frame = ConfigParser.handle_true_false(frame)
      @frame_width = frame_width.to_i
      @value = ''
    end

    def value=(data)
      if @value != data
        @value = data
        @parent_layout.update_widget
      end
    end

    def draw_widget(painter, on_state)
      painter.save
      painter.setPen(@pen)
      painter.setFont(@font)
      painter.drawText(@x, @y, @value.to_s)
      if @frame
        h = @fm.height
        w = @fm.width(@value.to_s)
        @pen.setWidth(@frame_width)
        painter.drawLine(@x-5, @y+5, @x+w+10, @y+5) # bottom line
        painter.drawLine(@x-5, @y+5, @x-5, @y-h-5) # left line
        painter.drawLine(@x-5, @y-h-5, @x+w+10, @y-h-5) # top line
        painter.drawLine(@x+w+10, @y+5, @x+w+10, @y-h-5) # right line
      end
      painter.restore
    end
  end

end # module Cosmos
