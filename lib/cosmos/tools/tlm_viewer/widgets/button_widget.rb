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

    def initialize(parent_layout, button_text, string_to_eval)
      super()
      setText(button_text.to_s)
      connect(SIGNAL('clicked()')) { execute(string_to_eval.to_s) }
      parent_layout.addWidget(self) if parent_layout
    end

    def execute(code)
      # Disable the button while the code is executed to avoid thrashing
      setEnabled(false)
      # Spawn a new thread to avoid blocking the GUI. Users will have to
      # wrap any GUI interaction in Qt.execute_in_main_thread.
      Thread.new do
        begin
          @screen.instance_eval(code)
        rescue DRb::DRbConnError
          Qt.execute_in_main_thread do
            Qt::MessageBox.warning(parent.parentWidget, 'Error', "Error Connecting to Command and Telemetry Server")
          end
        rescue Exception => error
          message = error.message
          if error.message.include?("Qt methods cannot be called")
            message = "Error executing button code:\n#{code}"
          end
          Qt.execute_in_main_thread do
            Qt::MessageBox.warning(parent.parentWidget, 'Error', "#{error.class} : #{message}")
          end
        end
        Qt.execute_in_main_thread { self.setEnabled(true) }
      end
    end
  end
end
