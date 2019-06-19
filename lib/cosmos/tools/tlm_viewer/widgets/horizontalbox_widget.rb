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
  # Layout widget which layouts the enclosed widgets horizontally
  # in a visual box with header text.
  # Default spacing is 0 pixels
  class HorizontalboxWidget < Qt::HBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout, title = "", spacing = 0)
      super()
      box = Qt::GroupBox.new(title.to_s)
      setSpacing(spacing.to_i)
      box.setLayout(self)
      parent_layout.addWidget(box) if parent_layout
    end
  end
end
