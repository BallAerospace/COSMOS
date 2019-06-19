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
  # Layout widget which layouts the enclosed widgets horizontally.
  # Default spacing is 0 pixels.
  class HorizontalWidget < Qt::HBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout = nil, spacing = 0)
      super()
      setSpacing(spacing.to_i)
      parent_layout.addLayout(self) if parent_layout
    end
  end
end
