# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/tools/tlm_viewer/widgets/multi_widget'
require 'cosmos/tools/tlm_viewer/widgets/horizontal_widget'
require 'cosmos/tools/tlm_viewer/widgets/label_widget'
require 'cosmos/tools/tlm_viewer/widgets/value_widget'

module Cosmos
  # Displays a LabelWidget followed by a ValueWidget. The layout of the label with
  # respect to the value widget can be controlled by the align parameter.
  class LabelvalueWidget < Qt::Widget
    include Widget
    include MultiWidget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :WITH_UNITS, characters = 12, align = 'split')
      super(target_name, packet_name, item_name, value_type)
      setLayout(Qt::HBoxLayout.new)
      layout.setSpacing(0)
      layout.setContentsMargins(0,0,0,0)
      layout.addStretch(1) if align.downcase == 'right' || align.downcase == 'center'
      @widgets << LabelWidget.new(layout, item_name.to_s + ':')
      layout.addStretch(1) if align.downcase == 'split'
      @widgets << ValueWidget.new(layout, target_name, packet_name, item_name, value_type, characters.to_i)
      layout.addStretch(1) if align.downcase == 'left' || align.downcase == 'center'
      parent_layout.addWidget(self) if parent_layout
    end

    def self.takes_value?
      return true
    end

    # Normally the user would have to use SUBSETTING to set the label and
    # value parts of this widget. Since this widget is so common we overrides
    # set_setting so it's easier to set some of the more common things.
    def set_setting(setting_name, setting_values)
      case setting_name.upcase
      # Only apply TEXTALIGN to the value widget by default. It makes the label
      # look weird when doing LEFT align which is the most common.
      when 'TEXTALIGN'
        @widgets[1].set_setting(setting_name, setting_values)
      when 'TEXTCOLOR' # Apply this to both widgets automatically
        @widgets[0].set_setting(setting_name, setting_values)
        @widgets[1].set_setting(setting_name, setting_values)
      else
        super(setting_name, setting_values)
      end
    end
  end
end
