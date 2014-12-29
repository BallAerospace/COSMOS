# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/choosers/combobox_chooser'

module Cosmos

  class SelectDialog
    attr_accessor :result

    def initialize(parent, label_text, items, title = 'Select Item')
      @result = nil

      dialog = Qt::Dialog.new(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle(title)
      dialog_layout = Qt::VBoxLayout.new

      chooser = ComboboxChooser.new(dialog, label_text, items)
      dialog_layout.addWidget(chooser)

      button_layout = Qt::HBoxLayout.new
      ok = Qt::PushButton.new("Ok")
      ok.connect(SIGNAL('clicked()')) do
        dialog.accept()
      end
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) do
        dialog.reject()
      end
      button_layout.addWidget(cancel)
      dialog_layout.addLayout(button_layout)

      dialog.setLayout(dialog_layout)
      dialog.raise
      if dialog.exec == Qt::Dialog::Accepted
        @result = chooser.string
      else
        @result = nil
      end
      dialog.dispose
    end
  end # class TlmEditDialog

end # module Cosmos
