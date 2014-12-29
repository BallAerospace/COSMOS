# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/layout_widget'

module Cosmos

  class ScrollwindowWidget < Qt::VBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout)
      super()
      @widget = Qt::Widget.new
      @widget.setLayout(self)
      parent_layout.addWidget(@widget) if parent_layout
      @parent_layout = parent_layout
    end

    def complete
      scroll = Qt::ScrollArea.new
      scroll.setWidget(@widget)
      @parent_layout.addWidget(scroll)
    end
  end

end # module Cosmos
