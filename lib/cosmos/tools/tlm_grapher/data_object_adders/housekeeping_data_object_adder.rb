# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
require 'cosmos/tools/tlm_grapher/data_objects/housekeeping_data_object'
require 'cosmos/gui/widgets/full_text_search_line_edit'

module Cosmos

  # Widget for adding a housekeeping data object to a plot
  class HousekeepingDataObjectAdder < Qt::Widget

    # Callback called when the add button is pressed - call(data_object)
    attr_accessor :add_data_object_callback

    # @parent [Qt::Widget] Parent widget to hold this frame
    # @orientation [Integer] How to layout the frame.
    #   Must be Qt::Horizontal or Qt::Vertical.
    def initialize(parent, orientation = Qt::Horizontal)
      super(parent)
      @overall_frame = Qt::VBoxLayout.new
      @overall_frame.setContentsMargins(0,0,0,0)

      @search_layout = Qt::HBoxLayout.new
      @search_label = Qt::Label.new("Add Housekeeping Data Object: ", self)
      @search_box = FullTextSearchLineEdit.new(self)
      @search_box.setStyleSheet("padding-right: 20px;padding-left: 5px;background: url(#{File.join(Cosmos::PATH, 'data', 'search-14.png')});background-position: right;background-repeat: no-repeat;")
      @search_box.completion_list = System.telemetry.all_item_strings(false, nil)
      @search_box.callback = lambda do |tlm|
        split_tlm = tlm.split(" ")
        if split_tlm.length == 3
          target_name = split_tlm[0].upcase
          packet_name = split_tlm[1]
          item_name = split_tlm[2]
          begin
            System.telemetry.packet_and_item(target_name, packet_name, item_name)
            add_data_object(target_name, packet_name, item_name)
          rescue
            # Does not exist
          end
        end
      end
      @search_layout.addWidget(@search_label)
      @search_layout.addWidget(@search_box)
      @overall_frame.addLayout(@search_layout)
      setLayout(@overall_frame)
      @add_data_object_callback = nil
    end

    # Update choices
    def update
      # Do nothing for now
    end

    # Adds a data object when the add button is pressed
    def add_data_object(target_name, packet_name, item_name)
      data_object = HousekeepingDataObject.new
      data_object.set_item(target_name, packet_name, item_name)
      @add_data_object_callback.call(data_object) if @add_data_object_callback
    end

  end # class HousekeepingDataObjectAdder

end # module Cosmos
