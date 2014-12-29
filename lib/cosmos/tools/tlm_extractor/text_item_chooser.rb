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

module Cosmos

  # Allow entry of a column name and some text
  class TextItemChooser < Qt::Widget

    # Callback called when the button is pressed - call(column_name, text)
    attr_accessor :button_callback

    # @param parent [Qt::Widget] Parent of this widget
    def initialize(parent)

      super(parent)
      @overall_frame = Qt::HBoxLayout.new(self)
      @overall_frame.setContentsMargins(0,0,0,0)

      # Column Name
      @column_name_layout = Qt::HBoxLayout.new
      @column_name_label = Qt::Label.new('Column Name:')
      @column_name_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed)
      @column_name_layout.addWidget(@column_name_label)
      @column_name = Qt::LineEdit.new('')
      @column_name_layout.addWidget(@column_name)
      @overall_frame.addLayout(@column_name_layout)

      # Text
      @text_layout = Qt::HBoxLayout.new
      @text_label = Qt::Label.new('Text:')
      @text_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed)
      @text_layout.addWidget(@text_label)
      @text = Qt::LineEdit.new('')
      @text_layout.addWidget(@text)
      @overall_frame.addLayout(@text_layout)

      # Button
      @button = Qt::PushButton.new('Add Text')
      @button.connect(SIGNAL('clicked()')) do
        @button_callback.call(@column_name.text, @text.text) if @button_callback
      end
      @overall_frame.addWidget(@button)

      # Initialize instance variables
      @button_callback = nil
    end

  end # class TextItemChooser

end # module Cosmos
