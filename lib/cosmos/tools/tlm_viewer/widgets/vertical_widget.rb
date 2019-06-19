# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and VerticalWidget class.   This class implements
# a vertical layout manager

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/layout_widget'

module Cosmos
  # Layout widget which layouts the enclosed widgets vertically.
  # Default spacing is 3 pixels and widgets are packed by inserting
  # a stretch at the end of the added widgets.
  class VerticalWidget < Qt::VBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout = nil, spacing = 3, pack = true)
      super()
      setSpacing(spacing.to_i)
      parent_layout.addLayout(self) if parent_layout
      @pack = ConfigParser::handle_true_false(pack)
    end

    def process_settings
      super()
      addStretch(1) if @pack
    end
  end
end
