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
  # Create a combobox. Typically used as a NAMED_WIDGET which is then
  # referenced by a BUTTON to perform an action. For example:
  #   NAMED_WIDGET COLLECT_TYPE COMBOBOX NORMAL SPECIAL
  #   BUTTON 'Start Collect' 'cmd("INST COLLECT with TYPE #{get_named_widget("COLLECT_TYPE").text}")'
  class ComboboxWidget < Qt::ComboBox
    include Widget

    def initialize(parent_layout, *combobox_items)
      super()
      addItems(combobox_items)
      self.maxVisibleItems = combobox_items.length > 6 ? 6 : combobox_items.length
      parent_layout.addWidget(self) if parent_layout
    end

    def text
      self.currentText
    end
  end
end
