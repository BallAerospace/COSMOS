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

  class ValueChooser < Qt::Widget

    # Callback for a new value entered into the text field
    attr_accessor :sel_command_callback

    def initialize(parent, label_text, initial_value, field_width = 20, fill = false)
      super(parent)
      @field_width = field_width

      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0,0,0,0)

      @label = Qt::Label.new(label_text)
      @label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      layout.addWidget(@label)
      layout.addStretch unless fill
      @value = Qt::LineEdit.new(initial_value.to_s)
      @value.setMinimumWidth(field_width)
      @callback_in_progress = false
      @value.connect(SIGNAL('editingFinished()')) do
        unless @callback_in_progress # Prevent double fire on loss of focus
          begin
            @callback_in_progress = true
            @sel_command_callback.call(string(), value()) if @sel_command_callback
          ensure
            @callback_in_progress = false
          end
        end
      end
      layout.addWidget(@value)
      setLayout(layout)

      @sel_command_callback = nil
    end

    # Returns the value as a string
    def string
      @value.text
    end

    # Returns the value as a string
    def value
      string()
    end

    # Sets the value of the text field
    def value=(new_value)
      @value.setText(new_value.to_s)
    end

  end
end

