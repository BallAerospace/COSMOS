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
  # Layout widget used within the TABBOOK widget to create tabs
  class TabitemWidget < Qt::VBoxLayout
    include Widget
    include LayoutWidget

    def initialize(parent_layout, text)
      super()
      w = Qt::Widget.new
      w.setLayout(self)
      parent_layout.addTab(w, text.to_s) if parent_layout
    end
  end
end
