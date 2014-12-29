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

  class TitleWidget < Qt::Label
    include Widget

    def initialize(parent_layout, text)
      super()
      self.text = text.to_s.remove_quotes
      setFont(Cosmos.getFont("helvetica", 14, Qt::Font::Bold))
      setAlignment(Qt::AlignCenter)
      parent_layout.addWidget(self) if parent_layout
    end
  end

end # module Cosmos
