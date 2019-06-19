# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/multi_widget'
require 'cosmos/tools/tlm_viewer/widgets/label_widget'
require 'cosmos/tools/tlm_viewer/widgets/horizontalline_widget'

module Cosmos
  # Vertically stacks a LabelWidget on top of a HorizontallineWidget
  class SectionheaderWidget < Qt::Widget
    include Widget
    include MultiWidget

    def initialize(parent_layout, text)
      super()
      setLayout(Qt::VBoxLayout.new)
      layout.setSpacing(0)
      layout.setContentsMargins(0,0,0,0)
      @widgets << LabelWidget.new(layout, text.to_s)
      @widgets << HorizontallineWidget.new(layout)
      parent_layout.addWidget(self) if parent_layout
    end
  end
end
