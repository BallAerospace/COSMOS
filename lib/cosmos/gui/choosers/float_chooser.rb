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

  class FloatChooser < Qt::Widget

    # Callback for a new value entered into the text field
    attr_accessor :sel_command_callback

    def initialize(
      parent, label_text, initial_value,
      minimum_value = nil, maximum_value = nil, field_width = 20, fill = false
    )
      super(parent)
      @minimum_value = minimum_value
      @maximum_value = maximum_value
      @field_width   = field_width

      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0,0,0,0)

      @float_label = Qt::Label.new(label_text)
      @float_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      layout.addWidget(@float_label)
      layout.addStretch unless fill
      @float_value = Qt::LineEdit.new(initial_value.to_s)
      @float_value.setMinimumWidth(field_width)
      if minimum_value or maximum_value
        validator = Qt::DoubleValidator.new(@float_value)
        validator.setBottom(minimum_value) if minimum_value
        validator.setTop(maximum_value) if maximum_value
        validator.setNotation(Qt::DoubleValidator::StandardNotation)
        @float_value.setValidator(validator)
      end
      @callback_in_progress = false
      @float_value.connect(SIGNAL('editingFinished()')) do
        unless @callback_in_progress # Prevent double fire on loss of focus
          begin
            @callback_in_progress = true
            @sel_command_callback.call(string(), value()) if @sel_command_callback
          ensure
            @callback_in_progress = false
          end
        end
      end
      layout.addWidget(@float_value)
      setLayout(layout)

      @sel_command_callback = nil
    end

    # Returns the value as a string
    def string
      @float_value.text
    end

    # Returns the value as a float
    def value
      float_value = @float_value.text.to_f
      float_value = @minimum_value if @minimum_value and float_value < @minimum_value
      float_value = @maximum_value if @maximum_value and float_value > @maximum_value
      float_value
    end

    # Sets the value of the text field
    def value=(new_value)
      @float_value.setText(new_value.to_s)
    end

  end # class FloatChooser

end # module Cosmos
