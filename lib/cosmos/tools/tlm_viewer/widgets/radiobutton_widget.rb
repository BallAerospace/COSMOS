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

  class RadiobuttonWidget < Qt::RadioButton
    include Widget

    def initialize (parent_layout, radiobutton_text)
      super()
      setText(radiobutton_text.to_s)
      parent_layout.addWidget(self) if parent_layout
    end

    def checked?
      self.isChecked()
    end
  end

end # module Cosmos
