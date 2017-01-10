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
  # Widget which creates a horizontally laid out label and editable value.
  # A callback can be specified which is called once the value is changed.
  class ValueChooser < Qt::Widget
    # Callback for a new value entered into the text field
    attr_accessor :sel_command_callback

    # @param parent [Qt::Widget] Widget to parent this widget to
    # @param label_text [String] Text to place in the label
    # @param initial_value [String] Initial value to put in the value box
    # @param field_width [Integer] Minimum width of the value field
    # @param fill [Boolean] Whether to make this widget fill up the horizontal
    #   space allocated to it or be fixed width.
    def initialize(parent, label_text, initial_value, field_width = 20, fill = false)
      super(parent)
      @field_width = field_width

      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0, 0, 0, 0)

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

    # @return [String] The value as a string
    def value
      @value.text
    end
    alias string value

    # @param value [#to_s] String to set the value to
    def value=(value)
      @value.setText(value.to_s)
    end
  end
end
