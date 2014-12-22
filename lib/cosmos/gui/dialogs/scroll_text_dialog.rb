# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/gui/qt'

module Cosmos

  class ScrollTextDialog < Qt::Dialog
    def initialize(parent, title, text)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      setMinimumWidth(700)
      setMinimumHeight(400)

      setWindowTitle(title)
      # Intentionally don't load icon as this can cause loop of unexpected output running with --debug

      layout = Qt::VBoxLayout.new
      text.gsub!("\n","<br>")
      @text_edit = Qt::TextEdit.new(text, self)
      @text_edit.setReadOnly(true)
      layout.addWidget(@text_edit)

      self.setLayout(layout)
      self.raise
      self.exec
      self.dispose
    end
  end # class ScrollTextDialog

end # module Cosmos
