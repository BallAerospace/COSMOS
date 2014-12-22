# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  class StringChooser < Qt::Widget

    def initialize(
      parent, label_text, initial_value,
      field_width = 20, fill = false, read_only = false, alignment = Qt::AlignLeft | Qt::AlignVCenter
    )
      super(parent)
      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0,0,0,0)
      @string_label = Qt::Label.new(label_text)
      @string_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      if fill
        layout.addWidget(@string_label)
      else
        layout.addWidget(@string_label, 1)
      end
      layout.addStretch unless fill
      @string_value = Qt::LineEdit.new(initial_value.to_s)
      @string_value.setMinimumWidth(field_width)
      @string_value.setReadOnly(true) if read_only
      @string_value.setAlignment(alignment)
      layout.addWidget(@string_value)
      setLayout(layout)
    end

    # Returns the text field as a string
    def string
      @string_value.text
    end
    alias value string

    # Sets the value
    def value=(new_value)
      @string_value.setText(new_value.to_s)
    end

  end # class StringChooser

end # module Cosmos
