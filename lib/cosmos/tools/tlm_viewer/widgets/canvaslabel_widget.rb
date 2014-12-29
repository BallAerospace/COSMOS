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

  class CanvaslabelWidget
    include Widget

    def initialize(parent_layout, x, y, text, font_size = 12, color='black')
      super()
      @x = x.to_i
      @y = y.to_i
      @text = text
      @color = Cosmos::getColor(color)
      @font = Cosmos.getFont("helvetica", font_size.to_i)
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.save
      painter.setPen(@color)
      painter.setFont(@font)
      painter.drawText(@x, @y, @text)
      painter.restore
    end
  end

end # module Cosmos
