# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the Trendlimitsbar widget which
# is essentially a standard limits bar compound widget with the addition of
# a horizontal line indicating the previous trend position as well as another
# value box with the actual trend value.
# Trend = current value - value N samples ago.

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/multi_widget'
require 'cosmos/tools/tlm_viewer/widgets/value_widget'
require 'cosmos/tools/tlm_viewer/widgets/textfield_widget'
require 'cosmos/tools/tlm_viewer/widgets/trendbar_widget'

module Cosmos
  # Displays the current value followed by the current trend value
  # (the current value minus the value X samples ago) followed by a
  # limits bar with the defined limits. The limits bar shows the current
  # value as a vertical line and the trend value as a black dot.
  class TrendlimitsbarWidget < Qt::Widget
    include Widget
    include MultiWidget

    def initialize (parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS, trend_seconds = 60, characters = 12, width = 160, height = 25)
      super(target_name, packet_name, item_name, value_type)
      setLayout(Qt::HBoxLayout.new())
      layout.setSpacing(1)
      layout.setContentsMargins(0,0,0,0)
      @widgets << ValueWidget.new(layout, target_name, packet_name, item_name, value_type, characters)
      @widgets << TextfieldWidget.new(layout, 8)
      @widgets[-1].setReadOnly(true)
      @widgets << TrendbarWidget.new(layout, target_name, packet_name, item_name, value_type, trend_seconds, width, height, @widgets[-1])
      parent_layout.addWidget(self) if parent_layout
    end

    def self.takes_value?
      return true
    end
  end
end
