# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/label_widget'

module Cosmos
  # Creates a centered label with the specified font
  class TitleWidget < LabelWidget
    def initialize(parent_layout, text, font_name = "Helvetica", point_size = 14, bold = "BOLD", italic = false)
      super(parent_layout, text, font_name, point_size, bold, italic)
      setAlignment(Qt::AlignCenter)
    end
  end
end
