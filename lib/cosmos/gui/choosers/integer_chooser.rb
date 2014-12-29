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

  class IntegerChooser < Qt::Widget

    # Callback called when the value changes
    attr_accessor :sel_command_callback

    def initialize(
      parent, label_text, initial_value,
      minimum_value = nil, maximum_value = nil, field_width = 20, fill = false
    )
      super(parent)
      @minimum_value = minimum_value
      @maximum_value = maximum_value

      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0,0,0,0)

      @integer_label = Qt::Label.new(label_text)
      @integer_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      layout.addWidget(@integer_label)
      layout.addStretch() unless fill
      @integer_value = Qt::LineEdit.new(initial_value.to_s)
      @integer_value.setMinimumWidth(field_width)
      if minimum_value or maximum_value
        validator = Qt::IntValidator.new(@integer_value)
        validator.setBottom(minimum_value) if minimum_value
        validator.setTop(minimum_value) if maximum_value
        @integer_value.setValidator(validator)
      end
      @callback_in_progress = false
      @integer_value.connect(SIGNAL('editingFinished()')) do
        unless @callback_in_progress # Prevent double fire on loss of focus
          begin
            @callback_in_progress = true
            @sel_command_callback.call(string(), value()) if @sel_command_callback
          ensure
            @callback_in_progress = false
          end
        end
      end
      layout.addWidget(@integer_value)
      setLayout(layout)

      @sel_command_callback = nil
    end

    # Returns the value as a string
    def string
      @integer_value.text
    end

    # Returns the value as an integer
    def value
      integer_value = @integer_value.text.to_i
      integer_value = @minimum_value if @minimum_value and integer_value < @minimum_value
      integer_value = @maximum_value if @maximum_value and integer_value > @maximum_value
      integer_value
    end

    # Sets the value
    def value=(new_value)
      @integer_value.setText(new_value.to_s)
    end

  end # class IntegerChooser

end # module Cosmos
