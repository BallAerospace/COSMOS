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
require 'cosmos/tools/tlm_grapher/data_objects/housekeeping_data_object'
require 'cosmos/gui/widgets/full_text_search_line_edit'

module Cosmos

  # Widget for adding a housekeeping data object to a plot
  class HousekeepingDataObjectAdder < Qt::Widget

    # Callback called when the add button is pressed - call(data_object)
    attr_accessor :add_data_object_callback

    # @param parent [Qt::Widget] Parent widget to hold this frame
    # @param orientation [Integer] How to layout the frame.
    #   Must be Qt::Horizontal or Qt::Vertical.
    def initialize(parent, orientation = Qt::Horizontal)
      super(parent)
      @overall_frame = Qt::VBoxLayout.new
      @overall_frame.setContentsMargins(0,0,0,0)

      @search_layout = Qt::HBoxLayout.new
      @search_label = Qt::Label.new("Add Housekeeping Data Object: ", self)
      @search_box = FullTextSearchLineEdit.new(self)
      @search_box.completion_list = System.telemetry.all_item_strings(false, nil)
      @search_box.callback = lambda do |tlm|
        tlm.upcase!
        split_tlm = tlm.split(" ")
        if split_tlm.length == 3
          target_name = split_tlm[0]
          packet_name = split_tlm[1]
          # Check to see if the item name is followed by an array index,
          # notated by square brackets around an integer; i.e. ARRAY_ITEM[1]
          if (split_tlm[2] =~ /\[\d+\]$/)
            # We found an array index.
            # The $` special variable is the string before the regex match, i.e. ARRAY_ITEM
            item_name = $`
            # The $& special variable is the string matched by the regex, i.e. [1].
            # Strip off the brackets and then convert the array index to an integer.
            item_array_index = $&.gsub(/[\[\]]/, "").to_i
          else
            item_name = split_tlm[2]
            item_array_index = nil
          end
          begin
            packet, item = System.telemetry.packet_and_item(target_name, packet_name, item_name)
            # Default array index to zero if it wasn't specified.
            item_array_index = 0 if item.array_size and !item_array_index
            # Ignore array indicies for non-array items.
            item_array_index = nil if !item.array_size
            add_data_object(target_name, packet_name, item_name, item_array_index)
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
    def add_data_object(target_name, packet_name, item_name, item_array_index)
      data_object = HousekeepingDataObject.new
      data_object.set_item(target_name, packet_name, item_name)
      data_object.item_array_index = item_array_index
      @add_data_object_callback.call(data_object) if @add_data_object_callback
    end

  end # class HousekeepingDataObjectAdder

end # module Cosmos
