# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the ExceptionListDialog class.   This class
# provides a dialog box to show a list of exceptions.

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/exception_dialog'

module Cosmos

  # Displays a list of exceptions in a dialog box. Clicking on any of the
  # exceptions creates a new ExceptionDialog which shows the details.
  class ExceptionListDialog < Qt::Dialog
    def initialize(message, exception_list, title = 'COSMOS Exception List', parent = Qt::CoreApplication.instance.activeWindow)
      super(parent)
      self.window_title = title
      layout = Qt::VBoxLayout.new
      self.layout = layout

      @exception_list = exception_list

      layout.addWidget(Qt::Label.new(message))

      @list = Qt::ListWidget.new
      @exception_list.each_with_index do |exception, index|
        string = "#{index + 1}. #{exception.class} : #{exception.message}"
        Qt::ListWidgetItem.new(tr(string), @list)
      end
      layout.addWidget(@list)
      @list.connect(SIGNAL('itemSelectionChanged ()')) do
        ExceptionDialog.new(self, @exception_list[@list.currentRow], title, false)
      end

      ok_button = Qt::PushButton.new('Ok')
      connect(ok_button, SIGNAL('clicked()'), self, SLOT('accept()'))
      layout.addWidget(ok_button, 0, Qt::AlignCenter)

      # Constrain the maximum size in case the list is huge
      setMaximumSize(800, 600)
      # Ideally we resize to show the entire list
      resize(@list.width, @list.height)

      self.raise
      exec()
      dispose()
    end
  end # class ExceptionListDialog

end # module Cosmos

