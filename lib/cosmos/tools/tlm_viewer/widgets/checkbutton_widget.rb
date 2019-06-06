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
  # Create a checkbox. Typically used as a NAMED_WIDGET which is then
  # referenced by a BUTTON to perform an action. For example:
  #   NAMED_WIDGET CHECK CHECKBUTTON 'Ignore Hazardous Checks'
  #   BUTTON 'Send' 'if get_named_widget("CHECK").checked? then cmd_no_hazardous_check("INST CLEAR") else cmd("INST CLEAR") end'
  class CheckbuttonWidget < Qt::CheckBox
    include Widget

    def initialize(parent_layout, checkbutton_text, checked = 'UNCHECKED')
      super()
      setText(checkbutton_text.to_s)
      case checked.to_s
      when 'CHECKED'
        setChecked(true)
      when 'UNCHECKED'
        setChecked(false)
      else
        raise "Unknown option '#{checked}' given to #{self.class}"
      end
      parent_layout.addWidget(self) if parent_layout
    end

    def checked?
      self.isChecked()
    end
  end
end
