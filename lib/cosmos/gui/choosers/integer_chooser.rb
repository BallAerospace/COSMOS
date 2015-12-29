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
    def initialize(*args)
      super(*args)
    end

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

  class IntegerChooser < ValueChooser
    # Callback called when the value changes
    attr_accessor :sel_command_callback

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

    # Returns the value as an integer
    def value
      integer_value = @value.text.to_i
      integer_value = @minimum_value if @minimum_value && integer_value < @minimum_value
      integer_value = @maximum_value if @maximum_value && integer_value > @maximum_value
      integer_value
    end

  end
end

