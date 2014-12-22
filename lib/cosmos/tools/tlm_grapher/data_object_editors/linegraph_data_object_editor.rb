# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the LinegraphDataObjectEditor class.   This class
# provides dialog box content to create/edit linegraph data objects.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_editors/data_object_editor'
require 'cosmos/gui/choosers/float_chooser'
require 'cosmos/gui/choosers/combobox_chooser'

module Cosmos

  # Widget which creates an editor for a line graph data object
  class LinegraphDataObjectEditor < DataObjectEditor

    def initialize(parent)
      super(parent)
    end

    def set_data_object(data_object)
      local_layout = Qt::VBoxLayout.new
      local_layout.setContentsMargins(0,0,0,0)

      # Float Chooser for y_offset
      @y_offset = FloatChooser.new(self, 'Y Offset:', 0)
      @y_offset.value = data_object.y_offset if data_object.y_offset
      local_layout.addWidget(@y_offset)

      # Chooser for Y Axis
      @y_axis = ComboboxChooser.new(self, 'Y Axis:', LinegraphDataObject::Y_AXIS_CHOICES.map {|x| x.to_s})
      @y_axis.set_current(data_object.y_axis) if data_object.y_axis
      local_layout.addWidget(@y_axis)

      # Chooser for Horizontal Lines
      @button_layout = Qt::HBoxLayout.new
      @horizontal_label = Qt::Label.new('Horizontal Lines:')
      @button_layout.addWidget(@horizontal_label)
      @button_layout.addStretch()
      @add_button = Qt::PushButton.new('Add', self)
      @add_button.setAutoDefault(false)
      @add_button.connect(SIGNAL('clicked()')) { handle_add_button() }
      @button_layout.addWidget(@add_button)
      @delete_button = Qt::PushButton.new('Delete', self)
      @delete_button.setAutoDefault(false)
      @delete_button.connect(SIGNAL('clicked()')) { handle_delete_button() }
      @button_layout.addWidget(@delete_button)
      local_layout.addLayout(@button_layout)

      @horizontal_lines = Qt::ColorListWidget.new(self)
      @horizontal_lines.setMinimumHeight(50)
      sync_gui_lines_with_data_object(data_object)
      local_layout.addWidget(@horizontal_lines)
      @layout.addLayout(local_layout)

      super(data_object)
    end

    # Get the data object from the editor
    def get_data_object
      data_object = super()
      horizontal_lines = []
      index = 0
      @horizontal_lines.each do |list_item|
        horizontal_lines << [list_item.text.to_f, @horizontal_lines.getItemColor(index)]
        index += 1
      end
      data_object.horizontal_lines = horizontal_lines
      data_object.y_offset = @y_offset.value
      data_object.y_axis = @y_axis.symbol
      data_object
    end

    # Handle the Add Horizontal Line button being pressed
    def handle_add_button
      dialog = Qt::Dialog.new(self) #'Add Horizontal Line'
      layout = Qt::VBoxLayout.new
      colors = LinegraphDataObject::COLOR_LIST.clone
      color = ComboboxChooser.new(dialog, 'Color:', colors, color_chooser: true)
      layout.addWidget(color)
      y_value = FloatChooser.new(dialog, 'Y Value:', 0.0)
      layout.addWidget(y_value)

      # Create OK and Cancel buttons
      button_layout = Qt::HBoxLayout.new
      ok_button = Qt::PushButton.new('OK')
      ok_button.connect(SIGNAL('clicked()')) { dialog.accept }
      button_layout.addWidget(ok_button)
      cancel_button = Qt::PushButton.new('Cancel')
      cancel_button.connect(SIGNAL('clicked()')) { dialog.reject }
      button_layout.addWidget(cancel_button)

      layout.addLayout(button_layout)
      dialog.setLayout(layout)
      result = dialog.exec
      if result != 0
        # Horizontal Line Added
        @horizontal_lines.addItemColor(y_value.string, color.string)
      end
      dialog.dispose
    end

    # Handle the delete horizontal line button being pressed
    def handle_delete_button
      horizontal_line_indexes = selected_horizontal_lines()
      unless horizontal_line_indexes.empty?
        horizontal_line_indexes.reverse.each do |index|
          @horizontal_lines.takeItemColor(index)
        end
      end
    end

    protected

    # Update the horizontal line list to match the data object
    def sync_gui_lines_with_data_object(data_object)
      @horizontal_lines.clearItems
      data_object.horizontal_lines.each {|y_value, color| @horizontal_lines.addItemColor(y_value.to_s, color)}
    end

    # Returns an array of the indexes of the selected horizontal lines
    def selected_horizontal_lines
      selected = []
      index = 0
      @horizontal_lines.each do |list_item|
        selected << index if list_item.selected?
        index += 1
      end
      selected
    end

  end # class LinegraphDataObjectEditor

end # module Cosmos
