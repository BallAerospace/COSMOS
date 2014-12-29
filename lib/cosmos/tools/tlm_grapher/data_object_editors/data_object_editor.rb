# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the DataObjectEditor class.   This class
# provides a base class to create/edit data objects.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_objects/data_object'
require 'cosmos/gui/choosers/combobox_chooser'

module Cosmos

  # Widget which creates an editor for a data object
  class DataObjectEditor < Qt::Widget

    # Overall frame of the editor for this data object type
    attr_accessor :frame

    def initialize(parent)
      super(parent)
      @layout = Qt::VBoxLayout.new
    end

    def set_data_object(data_object)
      @data_object = data_object

      # Chooser for Assigned Color - nil equals none assigned represented as ' '
      colors = DataObject::COLOR_LIST.clone
      colors.unshift(' ')
      @assigned_color = ComboboxChooser.new(parent, 'Assigned Color:', colors, color_chooser: true)
      @assigned_color.set_current(data_object.assigned_color) if data_object.assigned_color
      @layout.addWidget(@assigned_color)
      @label = Qt::Label.new('* Changing this item will cause loss of existing data')
      @layout.addWidget(@label)
      setLayout(@layout)

      @frame = parent unless defined? @frame
    end

    # Gets the data object from the editor
    def get_data_object
      assigned_color = @assigned_color.string
      if assigned_color.strip.empty?
        @data_object.assigned_color = nil
      else
        @data_object.assigned_color = assigned_color
        @data_object.color = assigned_color
      end
      @data_object
    end

  end # class DataObjectEditor

end # module Cosmos
