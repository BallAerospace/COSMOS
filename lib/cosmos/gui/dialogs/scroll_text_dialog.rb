# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/gui/qt'

module Cosmos
  # Dialog which creates a read only list of text
  class ScrollTextDialog < Qt::Dialog
    TEXT_MARGIN = 30
    SCREEN_WIDTH_MARGIN = 40
    SCREEN_HEIGHT_MARGIN = 100

    # @param parent [Qt::Widget] Parent of this dialog
    # @param title [String] Dialog title
    # @param text [String] Text to display
    def initialize(parent, title, text)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      setWindowTitle(title)

      layout = Qt::VBoxLayout.new
      @text_edit = Qt::TextEdit.new(text.gsub("\n","<br>"), self)
      @text_edit.setReadOnly(true)
      layout.addWidget(@text_edit)

      rec = Qt::Application::desktop.screenGeometry()
      font = @text_edit.document().defaultFont()
      font_metrics = Qt::FontMetrics.new(font)
      text_size = font_metrics.size(0, text)
      text_width = text_size.width + TEXT_MARGIN
      text_height = text_size.height + TEXT_MARGIN
      width = text_width > rec.width ? rec.width - SCREEN_WIDTH_MARGIN : text_width
      height = text_height > rec.height ? rec.height - SCREEN_HEIGHT_MARGIN : text_height
      @text_edit.setMinimumSize(width, height)

      self.setLayout(layout)
      self.raise
      self.exec
      self.dispose
    end
  end
end
