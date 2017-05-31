# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and TlmEditDialog class.   This class
# is used to edit a telemetry items settings typically on a right click.

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/script'

module Cosmos
  # Dialog which allows the user to enable or disable limits checking for the
  # given item.
  class TlmEditDialog
    # @param parent [Qt::Widget] Dialog parent
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param item_name [String] Name of the item
    def initialize(parent, target_name, packet_name, item_name)
      begin
        limits_enabled = limits_enabled?(target_name, packet_name, item_name)
      rescue RuntimeError
        # Error most likely due to LATEST packet - Ignore
        limits_enabled = nil
      end

      # Check for nil because true and false are both valid values
      if limits_enabled.nil?
        Qt::MessageBox.information(parent, "Edit Settings for #{target_name} #{packet_name} #{item_name}",
          'No Editable Fields for this Item')
        return
      end

      dialog = Qt::Dialog.new(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle("Edit Settings for #{target_name} #{packet_name} #{item_name}")
      dialog_layout = Qt::VBoxLayout.new
      dialog_layout.addWidget(Qt::Label.new("Warning: Edits affect all COSMOS tools, not just this application!"))

      check_layout = Qt::HBoxLayout.new
      check_label = Qt::Label.new("Limits Checking Enabled:")
      checkbox = Qt::CheckBox.new
      checkbox.setChecked(limits_enabled)
      check_label.setBuddy(checkbox)
      check_layout.addWidget(check_label)
      check_layout.addWidget(checkbox)
      dialog_layout.addLayout(check_layout)

      button_layout = Qt::HBoxLayout.new
      ok = Qt::PushButton.new("Ok")
      ok.connect(SIGNAL('clicked()')) { dialog.accept }
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) { dialog.reject }
      button_layout.addWidget(cancel)
      dialog_layout.addLayout(button_layout)

      dialog.setLayout(dialog_layout)
      dialog.show
      dialog.raise
      if dialog.exec == Qt::Dialog::Accepted
        if checkbox.isChecked()
          enable_limits(target_name, packet_name, item_name)
        else
          disable_limits(target_name, packet_name, item_name)
        end
      end
      dialog.dispose
    rescue DRb::DRbConnError
      # Just do nothing
    end
  end
end
