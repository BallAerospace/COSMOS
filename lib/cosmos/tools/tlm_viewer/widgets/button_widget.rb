# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the ButtonWidget class.

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/gui/utilities/script_module_gui'

module Cosmos

  class ButtonWidget < Qt::PushButton
    include Widget

    def initialize (parent_layout, button_text, string_to_eval)
      super()
      setText(button_text.to_s)
      connect(SIGNAL('clicked()')) do
        begin
          @screen.instance_eval(string_to_eval.to_s)
        rescue DRb::DRbConnError
          Qt::MessageBox.warning(parent.parentWidget, 'Error', "Error Connecting to Command and Telemetry Server")
        rescue Exception => error
          Qt::MessageBox.warning(parent.parentWidget, 'Error', "#{error.class} : #{error.message}")
        end
      end
      parent_layout.addWidget(self) if parent_layout
    end

  end

end # module Cosmos
