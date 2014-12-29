# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  class FileChooser < Qt::Widget

    # Callback for a chosen filename
    attr_accessor :callback

    def initialize(
      parent, label_text, initial_value, button_text, file_path,
      field_width = 20, fill = false, extensions = nil
    )
      super(parent)

      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0,0,0,0)

      @file_label = Qt::Label.new(label_text)
      @file_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      layout.addWidget(@file_label)
      layout.addStretch unless fill

      @filename_value = Qt::LineEdit.new(initial_value.to_s)
      @filename_value.setMinimumWidth(field_width)
      @filename_value.setReadOnly(true)
      layout.addWidget(@filename_value)

      @select_button = Qt::PushButton.new(button_text)
      @select_button.connect(SIGNAL('clicked()')) do
        if extensions
          filename = Qt::FileDialog.getOpenFileName(self, button_text, file_path, extensions)
        else
          filename = Qt::FileDialog.getOpenFileName(self, button_text, file_path)
        end
        if !filename.to_s.empty?
          @filename_value.text = filename.to_s
          @callback.call(@filename_value.text) if @callback
        end
      end
      layout.addWidget(@select_button)

      setLayout(layout)

      @callback = nil
    end

    def filename
      @filename_value.text
    end

    def filename=(filename)
      @filename_value.text = filename.to_s
    end

  end # class FloatChooser

end # module Cosmos
