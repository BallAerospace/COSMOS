# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/line_graph/line_graph'

module Cosmos

  class LineGraphDialog < Qt::Dialog

    attr_accessor :line_graph

    def initialize (title, width=400, height=300) 
      super(Qt::CoreApplication.instance.activeWindow)
      self.window_title = title
      @layout = Qt::VBoxLayout.new
      self.layout = @layout

      @line_graph = LineGraph.new(self)
      layout.addWidget(@line_graph)

      resize(width, height)
    end
  end

end # end module Cosmos
