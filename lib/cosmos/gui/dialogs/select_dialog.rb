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
  # Dialog which displays a label and comobox of items along with Ok and Cancel
  # buttons.
  class SelectDialog < Qt::Dialog
    # @return [String] The current combobox item when the dialog was accepte
    #   with the Ok button
    attr_accessor :result

    # @param parent [Qt::Widget] Parent of this dialog
    # @param label_text [String] Text to display for the label
    # @param items [Array<String>] Items to display in the combobox
    # @param title [String] Dialog title
    def initialize(parent, label_text, items, title = 'Select Item')
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @result = nil

      setWindowTitle(title)
      layout = Qt::VBoxLayout.new
      chooser = ComboboxChooser.new(self, label_text, items)
      layout.addWidget(chooser)

      button_layout = Qt::HBoxLayout.new
      ok = Qt::PushButton.new("Ok")
      ok.connect(SIGNAL('clicked()')) do
        accept()
      end
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) do
        reject()
      end
      button_layout.addWidget(cancel)
      layout.addLayout(button_layout)

      setLayout(layout)
      self.raise
      if self.exec == Qt::Dialog::Accepted
        @result = chooser.string
      else
        @result = nil
      end
      self.dispose
    end
  end
end
