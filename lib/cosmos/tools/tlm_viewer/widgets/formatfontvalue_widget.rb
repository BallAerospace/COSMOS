# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/formatvalue_widget'

module Cosmos

  # FormatfontvalueWidget class
  #
  # This class implements a value with configurable font values.  The font
  # can also be updated after it is created.
  # It inherits from the FormatvalueWidget class.
  class FormatfontvalueWidget < FormatvalueWidget

    def initialize (parent_layout, target_name, packet_name, item_name, format_string, value_type = :CONVERTED, characters = 12,
      font_name = 'arial', font_size = 100, font_weight = Qt::Font::Normal, font_slant = false)
      super(parent_layout, target_name, packet_name, item_name, format_string, value_type, characters)
      setFont(Cosmos.getFont(font_name, font_size.to_i, font_weight, font_slant))
      setFixedWidth(self.fontMetrics.width('X') * characters.to_i + 10)
    end

    def font=(font)
      setFont(font)
    end

  end

end # module Cosmos
