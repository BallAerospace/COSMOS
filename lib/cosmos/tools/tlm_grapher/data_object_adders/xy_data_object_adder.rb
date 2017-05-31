# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the HousekeepingDataObjectAdder
# This provides a quick way to add housekeeping data objects.

require 'cosmos'
require 'cosmos/gui/choosers/telemetry_chooser'
require 'cosmos/gui/choosers/combobox_chooser'
require 'cosmos/tools/tlm_grapher/data_objects/xy_data_object'

module Cosmos

  # Widget for adding a X-Y data object to a plot
  class XyDataObjectAdder < Qt::Widget

    # Callback called when the add button is pressed - call(data_object)
    attr_accessor :add_data_object_callback

    # @param parent [Qt::Widget] Parent widget to hold this frame
    # @param orientation [Integer] How to layout the frame.
    #   Must be Qt::Horizontal or Qt::Vertical.
    def initialize(parent, orientation = Qt::Horizontal)
      super(parent)
      if orientation == Qt::Horizontal
        @overall_frame = Qt::HBoxLayout.new
      else
        @overall_frame = Qt::VBoxLayout.new
      end
      @overall_frame.setContentsMargins(0,0,0,0)

      # Chooser for packet and y item
      @telemetry_chooser = TelemetryChooser.new(self, orientation, true, false, true, true)
      @telemetry_chooser.update
      @overall_frame.addWidget(@telemetry_chooser)
      @telemetry_chooser.target_changed_callback = method(:packet_changed_callback)
      @telemetry_chooser.packet_changed_callback = method(:packet_changed_callback)
      @telemetry_chooser.item_label.text = 'Y Item:'

      # Chooser for x item
      x_item_names = @telemetry_chooser.item_names
      @x_item_name = ComboboxChooser.new(self, 'X Item:', x_item_names)
      @x_item_name.set_current('RECEIVED_TIMESECONDS')
      @overall_frame.addWidget(@x_item_name)

      # Button to add data object
      @add_data_object_button = Qt::PushButton.new('Add XY Data Object')
      @add_data_object_button.connect(SIGNAL('clicked()')) do
        add_data_object()
      end
      @overall_frame.addWidget(@add_data_object_button)

      setLayout(@overall_frame)

      @add_data_object_callback = nil
    end

    # Update choices
    def update
      @telemetry_chooser.update
      x_item_names = @telemetry_chooser.item_names
      @x_item_name.update_items(x_item_names, false)
      @x_item_name.set_current('RECEIVED_TIMESECONDS')
    end

    # Adds a data object when the add button is pressed
    def add_data_object
      data_object = XyDataObject.new
      data_object.target_name = @telemetry_chooser.target_name
      data_object.packet_name = @telemetry_chooser.packet_name
      data_object.y_item_name = @telemetry_chooser.item_name
      data_object.x_item_name = @x_item_name.string

      @add_data_object_callback.call(data_object) if @add_data_object_callback
    end

    protected

    # Handles the target or packet name changing
    def packet_changed_callback(target_name = nil, packet_name = nil)
      x_item_names = @telemetry_chooser.item_names
      @x_item_name.update_items(x_item_names, false)
      @x_item_name.set_current('RECEIVED_TIMESECONDS')
    end

  end # class XyDataObjectAdder

end # module Cosmos
