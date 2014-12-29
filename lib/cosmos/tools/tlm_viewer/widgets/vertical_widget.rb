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

  class VerticalWidget < Qt::VBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout = nil, vSpacing = 3)
      super()
      setSpacing(vSpacing.to_i)
      parent_layout.addLayout(self) if parent_layout
    end

    def process_settings
      super()
      addStretch(1)
    end
  end

end # module Cosmos
