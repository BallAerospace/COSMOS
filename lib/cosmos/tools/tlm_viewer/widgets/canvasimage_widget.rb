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

  class CanvasimageWidget
    include Widget

    def initialize(parent_layout, filename, x, y)
      super()
      @x = x.to_i
      @y = y.to_i
      @image = nil
      filename = File.join(::Cosmos::USERPATH, 'config', 'data', filename)
      unless File.exist?(filename)
        raise "Can't find the file #{filename} in #{::Cosmos::USERPATH}/config/data"
      end
      @image = Qt::Image.new(filename)
      parent_layout.add_repaint(self)
    end

    def paint(painter)
      painter.drawImage(@x, @y, @image) if @image
    end

    def dispose
      super()
      @image.dispose
    end
  end

end # module Cosmos
