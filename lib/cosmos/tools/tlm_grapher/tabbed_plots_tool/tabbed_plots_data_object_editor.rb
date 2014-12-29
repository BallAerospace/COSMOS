# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_editors/data_object_editor'
require 'cosmos/tools/tlm_grapher/data_object_editors/linegraph_data_object_editor'
require 'cosmos/tools/tlm_grapher/data_object_editors/housekeeping_data_object_editor'
require 'cosmos/tools/tlm_grapher/data_object_editors/xy_data_object_editor'
require 'cosmos/tools/tlm_grapher/data_object_editors/singlexy_data_object_editor'

module Cosmos

  # Dialog which allows the user to edit the data object
  class TabbedPlotsDataObjectEditor < Qt::Dialog

    def initialize(parent, title, data_object_types, data_object = nil)
      # Call base class constructor
      super(parent)
      setWindowTitle(title)

      layout = Qt::VBoxLayout.new

      unless data_object
        # Create combobox to select data object type
        @combobox = Qt::ComboBox.new(self)
        data_object_types.each {|data_object_type| @combobox.addItem(data_object_type.to_s.upcase)}
        @combobox.setMaxVisibleItems(data_object_types.length)
        @combobox.connect(SIGNAL('currentIndexChanged(int)')) { handle_data_object_type_change(data_object) }
        combo_layout = Qt::FormLayout.new()
        combo_layout.addRow('Data Object Type:', @combobox)
        layout.addLayout(combo_layout)

        # Separator before actual editing dialog
        sep1 = Qt::Frame.new
        sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
        layout.addWidget(sep1)
      else
        setWindowTitle(title + " : #{data_object.data_object_type}")
      end

      # Create editor class for specific data object type
      # Defaults to data_object_types[0] if a data object was not given
      if data_object
        data_object_type = data_object.class.to_s[0..-11].downcase
        data_object_type = data_object_type.split('::')[-1] # Remove Cosmos:: if present
      else
        data_object_type = data_object_types[0].to_s.downcase
      end
      @editor_layout = Qt::VBoxLayout.new
      layout.addLayout(@editor_layout)
      @editor = Cosmos.require_class(data_object_type + '_data_object_editor.rb').new(self)
      @editor.set_data_object(data_object)
      @editor_layout.addWidget(@editor)

      # Separator before buttons
      sep2 = Qt::Frame.new
      sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      layout.addWidget(sep2)
      layout.addStretch

      # Create OK and Cancel buttons
      ok_button = Qt::PushButton.new('Ok')
      ok_button.setDefault(true)
      connect(ok_button, SIGNAL('clicked()'), self, SLOT('accept()'))
      cancel_button = Qt::PushButton.new('Cancel')
      connect(cancel_button, SIGNAL('clicked()'), self, SLOT('reject()'))
      button_layout = Qt::HBoxLayout.new()
      button_layout.addWidget(ok_button)
      button_layout.addWidget(cancel_button)
      layout.addLayout(button_layout)

      setLayout(layout)
    end # def initialize

    # Executes the dialog box
    def execute
      return_value = nil
      result = exec()
      if result == Qt::Dialog::Accepted
        return_value = @editor.get_data_object
      end
      dispose()
      return return_value
    end # def execute

    protected

    # Handles the data object type changing
    def handle_data_object_type_change(data_object)
      data_object_type = @combobox.text.downcase
      @editor_layout.removeWidget(@editor)
      @editor.dispose
      @editor = Cosmos.require_class(data_object_type + '_data_object_editor.rb').new(self)
      @editor.set_data_object(data_object)
      @editor_layout.addWidget(@editor)
    end

  end # class TabbedPlotsDataObjectEditor

end # module Cosmos
