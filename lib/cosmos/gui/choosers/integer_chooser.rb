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
  class IntegerChooserIntValidator < Qt::IntValidator
    def fixup(input)
      begin
        value = input.to_i
        if value < bottom()
          # Handle less than bottom
          parent().setText(bottom().to_s)
        elsif value > top()
          # Handle greater than top
          parent().setText(top().to_s)
        elsif input != value.to_s
          # Handle poorly formatted (only known case is float given as starting value)
          parent().setText(value.to_s)
        end
      rescue Exception => err
        # Oh well no fixup
      end
    end
  end

  # Widget which creates a horizontally laid out label and editable integer value.
  # Minimum and maximum values can be specified to perform input validation.
  # A callback can be specified which is called once the value is changed.
  class IntegerChooser < ValueChooser
    # @param parent (see ValueChooser#initialize)
    # @param label_text (see ValueChooser#initialize)
    # @param initial_value (see ValueChooser#initialize)
    # @param minimum_value [Integer] Minimum allowable value
    # @param maximum_value [Integer] Maximum allowable value
    # @param field_width (see ValueChooser#initialize)
    # @param fill (see ValueChooser#initialize)
    def initialize(parent, label_text, initial_value,
                   minimum_value = nil, maximum_value = nil,
                   field_width = 20, fill = false)
      super(parent, label_text, initial_value, field_width, fill)
      @minimum_value = minimum_value
      @maximum_value = maximum_value

      validator = IntegerChooserIntValidator.new(@value)
      validator.setBottom(minimum_value) if minimum_value
      validator.setTop(maximum_value) if maximum_value
      @value.setValidator(validator)
    end

    # @return [Integer] Value as an integer. If minimum and/or maximum values were
    #   specified and the the value falls outside, it will be set to the
    #   minimum or maximum as appropriate.
    def value
      integer_value = @value.text.to_i
      integer_value = @minimum_value if @minimum_value && integer_value < @minimum_value
      integer_value = @maximum_value if @maximum_value && integer_value > @maximum_value
      integer_value
    end
  end
end
