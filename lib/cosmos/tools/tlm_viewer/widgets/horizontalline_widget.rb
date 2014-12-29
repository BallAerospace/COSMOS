# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  class HorizontallineWidget < Qt::Frame
    include Widget

    def initialize(parent_layout)
      super()
      setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      parent_layout.addWidget(self) if parent_layout
    end

  end

end # module Cosmos
