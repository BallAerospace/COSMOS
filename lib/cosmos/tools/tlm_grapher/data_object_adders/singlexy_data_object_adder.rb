# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the SinglexyDataObjectAdder
# This provides a quick way to add single x-y data objects.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_adders/xy_data_object_adder'
require 'cosmos/tools/tlm_grapher/data_objects/singlexy_data_object'

module Cosmos

  # Widget for adding a single X-Y data object to a plot
  class SinglexyDataObjectAdder < XyDataObjectAdder

    # @parent [Qt::Widget] Parent widget to hold this frame
    # @orientation [Integer] How to layout the frame.
    #   Must be Qt::Horizontal or Qt::Vertical.
    def initialize(parent, orientation = Qt::Horizontal)
      super(parent, orientation)
      @add_data_object_button.text = 'Add Single-XY Data Object'
    end

    # Adds a data object when the add button is pressed
    def add_data_object
      data_object = SinglexyDataObject.new
      data_object.target_name = @telemetry_chooser.target_name
      data_object.packet_name = @telemetry_chooser.packet_name
      data_object.y_item_name = @telemetry_chooser.item_name
      data_object.x_item_name = @x_item_name.string

      @add_data_object_callback.call(data_object) if @add_data_object_callback
    end

  end # class SinglexyDataObjectAdder

end # module Cosmos
