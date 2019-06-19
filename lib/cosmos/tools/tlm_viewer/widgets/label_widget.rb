# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # Displays a text label
  class LabelWidget < Qt::Label
    include Widget

    def initialize(parent_layout, text, font_family = nil, point_size = nil, bold = nil, italic = false)
      super()
      font = self.font
      font.setFamily(font_family) unless ConfigParser.handle_nil(font_family).nil?
      font.setPointSize(point_size.to_i) unless ConfigParser.handle_nil(point_size).nil?
      font.setBold(true) if bold == 'BOLD'
      font.setItalic(true) if ConfigParser::handle_true_false(italic) == true
      setFont(font)
      self.text = text.to_s.remove_quotes
      parent_layout.addWidget(self) if parent_layout
    end
  end
end
