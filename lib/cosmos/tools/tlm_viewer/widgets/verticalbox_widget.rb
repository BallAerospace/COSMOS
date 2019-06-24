# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and VerticalboxWidget class.   This class implements
# a vertical layout manager with a frame

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/layout_widget'

module Cosmos
  # Layout widget which layouts the enclosed widgets vertically
  # in a visual box with header text.
  # Default spacing is 3 pixels and widgets are packed by inserting
  # a stretch at the end of the added widgets.
  class VerticalboxWidget < Qt::VBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout = nil, title = "", spacing = 3, pack = true)
      super()
      box = Qt::GroupBox.new(title.to_s)
      setSpacing(spacing.to_i)
      box.setLayout(self)
      parent_layout.addWidget(box) if parent_layout
      @pack = ConfigParser::handle_true_false(pack)
    end

    def process_settings
      super()
      addStretch(1) if @pack
    end
  end
end
