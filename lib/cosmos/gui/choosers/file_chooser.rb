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
  # Widget which creates a horizontally laid out label, value, and button that
  # opens a FileDialog to choose a file. A callback can be specified which is
  # called once the file is selected by the FileDialog.
  class FileChooser < Qt::Widget
    # Callback for a chosen filename
    attr_accessor :callback

    # @param parent [Qt::Widget] Widget to parent this widget to
    # @param label_text [String] Text to place in the label
    # @param initial_value [String] Initial value to put in the value box. Note
    #   this has no impact on the FileDialog.
    # @param button_text [String] Text to place on the button which launches
    #   the FileDialog
    # @param file_path [String] Default path which is used when initially
    #   opening the FileDialog
    # @param field_width [Integer] Minimum width of the value field
    # @param fill [Boolean] Whether to make this widget fill up the horizontal
    #   space allocated to it or be fixed width.
    # @param extensions [String] List of file filters which can be selected by
    #   the user. Must be formatted with the filter name followed by the
    #   extension in parens. Multiple filters must be separated by double
    #   semicolons. For example:
    #     "Images (*.png *.jpg);;Text files (*.txt)"
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

    # @return [String] The selected filename
    def filename
      @filename_value.text
    end

    # @param filename [String] Filename to set the value to
    def filename=(filename)
      @filename_value.text = filename.to_s
    end
  end
end
