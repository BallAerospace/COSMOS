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
  # Displays a progress bar based on the given telemetry item. The item should
  # return a value between 0 and 100 which will be used to update the progress.
  # You can also set a scale factor to multiply the telemetry item by before
  # setting the progress.
  class ProgressbarWidget < Qt::ProgressBar
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, scale_factor = 1.0, width = 80, value_type = :CONVERTED)
      super(target_name, packet_name, item_name, value_type)
      @scale_factor = scale_factor.to_f
      setFixedWidth(width.to_i)
      parent_layout.addWidget(self) if parent_layout
    end

    def value=(value)
      value = (value.to_f * @scale_factor).to_i
      # Truncate to 100 because otherwise it will not display
      value = 100 if value > 100
      setValue(value)
    end

    def ProgressbarWidget.takes_value?
      return true
    end
  end
end
