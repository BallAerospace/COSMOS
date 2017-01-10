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
  # Widget which creates a horizontally laid out label and editable string value.
  # A callback can be specified which is called once the value is changed.
  class StringChooser < ValueChooser
    # @param parent (see ValueChooser#initialize)
    # @param label_text (see ValueChooser#initialize)
    # @param initial_value (see ValueChooser#initialize)
    # @param field_width (see ValueChooser#initialize)
    # @param fill (see ValueChooser#initialize)
    # @param read_only [Boolean] Whether the string is editable
    # @param alignment [Integer] The alignment of the string value field
    def initialize(
      parent, label_text, initial_value,
      field_width = 20, fill = false, read_only = false,
      alignment = Qt::AlignLeft | Qt::AlignVCenter
    )
      super(parent, label_text, initial_value, field_width, fill)
      @value.setReadOnly(true) if read_only
      @value.setAlignment(alignment)
    end
  end
end
