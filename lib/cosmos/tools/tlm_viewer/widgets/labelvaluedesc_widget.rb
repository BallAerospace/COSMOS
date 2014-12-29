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
require 'cosmos/tools/tlm_viewer/widgets/label_widget'
require 'cosmos/tools/tlm_viewer/widgets/value_widget'

module Cosmos

  # LabelvalueWidget class
  #
  class LabelvaluedescWidget < Qt::Widget
    include Widget
    include MultiWidget

    def initialize(parent_layout, target_name, packet_name, item_name, description = "", value_type = :WITH_UNITS, characters = 12)
      super(target_name, packet_name, item_name, value_type)
      setLayout(Qt::HBoxLayout.new)
      layout.setSpacing(5)
      layout.setContentsMargins(0,0,0,0)
      description = ConfigParser.handle_nil(description)
      description = @item.description unless description
      @widgets << LabelWidget.new(layout, description.to_s)
      layout.addStretch(1)
      @widgets << ValueWidget.new(layout, target_name, packet_name, item_name, value_type, characters)
      parent_layout.addWidget(self) if parent_layout
    end

    def self.takes_value?
      return true
    end
  end

end # module Cosmos
