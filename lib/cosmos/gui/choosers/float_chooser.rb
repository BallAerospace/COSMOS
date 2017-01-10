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
  # Widget which creates a horizontally laid out label and editable float value.
  # Minimum and maximum values can be specified to perform input validation.
  # A callback can be specified which is called once the value is changed.
  class FloatChooser < ValueChooser
    # Callback for a new value entered into the text field
    attr_accessor :sel_command_callback

    # @param parent (see ValueChooser#initialize)
    # @param label_text (see ValueChooser#initialize)
    # @param initial_value (see ValueChooser#initialize)
    # @param minimum_value [Float] Minimum allowable value
    # @param maximum_value [Float] Maximum allowable value
    # @param field_width (see ValueChooser#initialize)
    # @param fill (see ValueChooser#initialize)
    def initialize(parent, label_text, initial_value,
                   minimum_value = nil, maximum_value = nil,
                   field_width = 20, fill = false)
      super(parent, label_text, initial_value, field_width, fill)
      @minimum_value = minimum_value
      @maximum_value = maximum_value

      validator = Qt::DoubleValidator.new(@value)
      validator.setBottom(minimum_value) if minimum_value
      validator.setTop(maximum_value) if maximum_value
      validator.setNotation(Qt::DoubleValidator::StandardNotation)
      @value.setValidator(validator)
    end

    # @return [Float] Value as a float. If minimum and/or maximum values were
    #   specified and the the value falls outside, it will be set to the
    #   minimum or maximum as appropriate.
    def value
      float_value = @value.text.to_f
      float_value = @minimum_value if @minimum_value && float_value < @minimum_value
      float_value = @maximum_value if @maximum_value && float_value > @maximum_value
      float_value
    end
  end
end

