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
require 'cosmos/tools/tlm_viewer/widgets/aging_widget'

module Cosmos
  # Displays a telemetry value that ages over time by the background fading
  # from white to grey if the telemetry value is not changing. A new telemetry
  # value updates the display back to a white background.
  class ValueWidget < Qt::LineEdit
    include Widget
    include AgingWidget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS, characters = 12)
      super(target_name, packet_name, item_name, value_type)
      setup_aging
      @characters = characters.to_i
      setReadOnly(true)
      setAlignment(Qt::AlignRight)
      setFixedWidth(fontMetrics.width('X') * @characters + 10)
      parent_layout.addWidget(self) if parent_layout
    end

    def value=(data)
      self.text = super(data)
      setColors(@foreground, @background)
    end

    def process_settings
      super
      process_aging_settings
    end
  end
end
