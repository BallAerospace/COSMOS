# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the CanvasWidget class.   This widget
# represents a canvas where draw-able widgets (such as images and lines) can be
# added.

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/layout_widget'

module Cosmos

  class CanvasWidget < Qt::Widget
    include Widget
    include LayoutWidget

    def initialize(parent_layout, width, height)
      super()
      @repaintObjects = []
      self.minimumWidth = width.to_i
      self.minimumHeight = height.to_i
      parent_layout.addWidget(self) if parent_layout
    end

    # add_repaint - Child widgets to the canvas must call add_repaint to register
    # itself with the canvas so that they are painted when the canvas is.  Note,
    # the order in which child widgets are painted is the order in which they
    # are created.
    def add_repaint(obj)
      @repaintObjects << obj
    end

    def paintEvent(event)
      begin
        painter = Qt::Painter.new
        painter.begin(self)
        painter.setBackgroundMode(Qt::OpaqueMode)
        painter.setBackground(Cosmos.getBrush(Qt::white))
        @repaintObjects.each do |obj|
          obj.paint(painter)
        end
        painter.end
        painter.dispose
      rescue Exception => err
        Cosmos.handle_fatal_exception(err)
      end
    end

    def update_widget
      self.update
    end
  end

end # module Cosmos
