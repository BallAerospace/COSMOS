# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/choosers/value_chooser'

module Cosmos

  class FloatChooserDoubleValidator < Qt::DoubleValidator
    def initialize(*args)
      super(*args)
    end

    def fixup(input)
      begin
        value = input.to_f
        if value < bottom()
          # Handle less than bottom
          parent().setText(bottom().to_s)
        elsif value > top()
          # Handle greater than top
          parent().setText(top().to_s)
        end
      rescue Exception => err
        # Oh well no fixup
      end
    end
  end

  class FloatChooser < ValueChooser
    # Callback for a new value entered into the text field
    attr_accessor :sel_command_callback

    def initialize(parent, label_text, initial_value,
                   minimum_value = nil, maximum_value = nil,
                   field_width = 20, fill = false)
      super(parent, label_text, initial_value, field_width, fill)
      @minimum_value = minimum_value
      @maximum_value = maximum_value

      validator = FloatChooserDoubleValidator.new(@value)
      validator.setBottom(minimum_value) if minimum_value
      validator.setTop(maximum_value) if maximum_value
      validator.setNotation(Qt::DoubleValidator::StandardNotation)
      @value.setValidator(validator)
    end

    # Returns the value as a float
    def value
      float_value = @value.text.to_f
      float_value = @minimum_value if @minimum_value && float_value < @minimum_value
      float_value = @maximum_value if @maximum_value && float_value > @maximum_value
      float_value
    end

  end
end

