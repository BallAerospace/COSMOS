# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and TlmGraphDialog class.   This class
# is used to open a telemetry grapher to graph a telemetry item, typically on
# a right click.

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/choosers/integer_chooser'
require 'cosmos/script'

module Cosmos
  # Dialog which allows the user to start graphing the given item.  If the
  # item is a fixed-size array, this allows the user to determine whether to
  # graph a single index within the array or all indices within the array.
  # If the item is a variable-sized array, this allows the user to select a
  # single index to graph.
  class TlmGraphDialog
    # @param parent [Qt::Widget] Dialog parent
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param item_name [String] Name of the item
    def initialize(parent, target_name, packet_name, item_name, replay = false)
      packet, item = System.telemetry.packet_and_item(target_name, packet_name, item_name)

      num_array_elements = 0
      if item.array_size
        if item.array_size > 0
          # Fixed size array
          num_array_elements = item.array_size / item.bit_size
        else
          # Variable size array
          num_array_elements = -1
        end
      end

      item_string = ""

      if num_array_elements != 0
        dialog = Qt::Dialog.new(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
        dialog.setWindowTitle("Select array index")
        dialog_layout = Qt::VBoxLayout.new
        dialog_layout.addWidget(Qt::Label.new("#{target_name} #{packet_name} #{item_name} is an array."))

        if num_array_elements > 0
          dialog_layout.addWidget(Qt::Label.new("Select array index to graph or graph all:"))
          index_chooser = IntegerChooser.new(parent, 'Array Index:', 0, 0, num_array_elements-1)
        else
          dialog_layout.addWidget(Qt::Label.new("Select array index to graph:"))
          index_chooser = IntegerChooser.new(parent, 'Array Index:', 0, 0)
        end
        dialog_layout.addWidget(index_chooser)

        checkbox = nil
        if num_array_elements > 0
          check_layout = Qt::HBoxLayout.new
          check_label = Qt::Label.new("Graph all:")
          checkbox = Qt::CheckBox.new
          checkbox.setChecked(false)
          check_label.setBuddy(checkbox)
          check_layout.addWidget(check_label)
          check_layout.addWidget(checkbox)
          dialog_layout.addLayout(check_layout)
        end

        button_layout = Qt::HBoxLayout.new
        ok = Qt::PushButton.new("Ok")
        ok.connect(SIGNAL('clicked()')) { dialog.accept }
        button_layout.addWidget(ok)
        cancel = Qt::PushButton.new("Cancel")
        cancel.connect(SIGNAL('clicked()')) { dialog.reject }
        button_layout.addWidget(cancel)
        dialog_layout.addLayout(button_layout)

        dialog.setLayout(dialog_layout)
        dialog.show
        dialog.raise
        if dialog.exec == Qt::Dialog::Accepted
          indices_to_graph = [index_chooser.value.to_i]
          if num_array_elements > 0 and checkbox.isChecked()
            indices_to_graph = (0..num_array_elements-1).to_a
          end
          indices_to_graph.each {|i| item_string << "-i \"#{target_name} #{packet_name} #{item_name}[#{i}]\" "}
        else
          # Cancel - graph nothing.
          item_string = ""
        end
        dialog.dispose
      else
        # This is not an array item, we don't need to create a dialog box...
        item_string << "-i \"#{target_name} #{packet_name} #{item_name}\" "
      end

      # Start grapher if necessary
      if !item_string.empty?
        options = "#{item_string} --system #{File.basename(System.initial_filename)}"
        options += " --replay" if replay
        Cosmos.run_cosmos_tool("TlmGrapher", options)
      end
    end
  end
end
